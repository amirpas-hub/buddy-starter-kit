/* BUDDY cockpit — interactive checklist + one-tap send queue.
   Kept in its own file so the daily cockpit rebuild can't break the JS.
   Contract the morning routine must emit:
     <div id="buddy-checklist" data-day="YYYY-MM-DD"> ... groups ...
        <label class="btask" data-id="STABLE_ID"><input type="checkbox"> <task text></label>
     </div>
     <span data-buddy-progress></span>            (optional progress readout)
     <div id="buddy-ready"></div>                  (one-tap send queue, filled from ready-to-send.json)
*/
(function () {
  function ready(fn){ if(document.readyState!=='loading'){fn();} else {document.addEventListener('DOMContentLoaded',fn);} }

  ready(function () {
    // ---------- 1. Interactive checklist (localStorage, keyed by day) ----------
    var box = document.getElementById('buddy-checklist');
    if (box) {
      var day = box.getAttribute('data-day') || 'x';
      var tasks = box.querySelectorAll('label.btask');
      var prog = document.querySelector('[data-buddy-progress]');

      function paint(){
        var done=0;
        tasks.forEach(function(l){
          var cb=l.querySelector('input[type=checkbox]');
          if(cb && cb.checked){ l.classList.add('done'); done++; }
          else { l.classList.remove('done'); }
        });
        if(prog){ prog.textContent = done + ' / ' + tasks.length + ' done'; }
      }

      tasks.forEach(function(l){
        var id = l.getAttribute('data-id'); if(!id) return;
        var key = 'buddy-todo:' + day + ':' + id;
        var cb = l.querySelector('input[type=checkbox]');
        if(!cb) return;
        try { if (localStorage.getItem(key) === '1') cb.checked = true; } catch(e){}
        cb.addEventListener('change', function(){
          try { localStorage.setItem(key, cb.checked ? '1' : '0'); } catch(e){}
          paint();
        });
      });
      paint();
    }

    // ---------- 1b. Next-call T-30 prep panel ----------
    var np = document.getElementById('buddy-nextcall');
    if (np) {
      fetch('next-call.json?ts=' + Date.now(), {cache:'no-store'})
        .then(function(r){ return r.ok ? r.json() : []; })
        .then(function(items){
          if(!items || !items.length){
            np.innerHTML = '<div class="flag">No external call in the next 30 min. BUDDY drops a prep brief here (and pings your Mac) 30 min before every merchant/partner call — follow-up recap + agenda, or a first-call overview.</div>';
            return;
          }
          np.innerHTML = items.map(function(it){
            var kind = it.kind==='first' ? 'First call' : 'Follow-up';
            var attend = (it.attendees||[]).join(', ');
            return '<div class="prio p1" style="align-items:flex-start">'
              + '<div class="num">⏰</div>'
              + '<div style="flex:1"><div class="pt">'+esc(it.company||'—')+' — '+esc(it.time||'')+' · <span style="opacity:.7">'+kind+'</span></div>'
              + '<div class="pd">'+(it.brief_html||esc(it.brief||''))
              + (attend?'<div style="opacity:.6;font-size:12px;margin-top:6px">'+esc(attend)+'</div>':'')+'</div></div></div>';
          }).join('');
        })
        .catch(function(){ np.innerHTML = '<div class="flag">Prep panel unavailable (next-call.json not found yet).</div>'; });
    }

    // ---------- 2. One-tap send queue (BUDDY-drafted, ready to send) ----------
    var slot = document.getElementById('buddy-ready');
    if (slot) {
      fetch('ready-to-send.json?ts=' + Date.now(), {cache:'no-store'})
        .then(function(r){ return r.ok ? r.json() : []; })
        .then(function(items){
          if(!items || !items.length){
            slot.innerHTML = '<div class="flag">Nothing queued right now. BUDDY drafts + queues follow-ups here automatically after each external call — one tap in Gmail to send.</div>';
            return;
          }
          var rows = items.map(function(it){
            var recips = (it.recipients||[]).join(', ');
            var when = it.ts ? (' · '+it.ts) : '';
            return '<tr><td><b>'+esc(it.company||'—')+'</b></td>'
                 + '<td>'+esc(it.subject||'')+'<div style="opacity:.6;font-size:12px">'+esc(recips)+when+'</div></td>'
                 + '<td><a class="sendbtn" href="'+esc(it.draftUrl||'#')+'" target="_blank" rel="noopener">Review &amp; send →</a></td></tr>';
          }).join('');
          slot.innerHTML = '<table><tr><th>Account</th><th>Draft</th><th></th></tr>'+rows+'</table>'
             + '<div class="flag">Drafted to external contacts you\'ve spoken to (never @shopify.com). The send tap is yours — that tap is the guardrail. Daily cap applies.</div>';
        })
        .catch(function(){
          slot.innerHTML = '<div class="flag">Send queue unavailable (ready-to-send.json not found yet).</div>';
        });
    }
    function esc(s){ return String(s).replace(/[&<>"]/g,function(c){return{'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c];}); }
  });
})();
