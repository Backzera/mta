(function(){
  var defaults = {
    enabled:true, style:'dot', color:'#FFFFFF', size:4, thickness:2,
    gap:4, opacity:255, outline:true, followAim:true, offsetX:0, offsetY:0
  };
  var state = Object.assign({}, defaults);

  function lua(action, payload){
    var json = JSON.stringify(payload || {});
    if(window.mta && typeof window.mta.triggerEvent === 'function'){
      window.mta.triggerEvent('crosshair:action', action, json);
    }
  }

  function num(key, value){
    state[key] = Number(value);
    live();
  }

  function live(){
    render();
    lua('change', state);
  }

  function setControls(){
    document.querySelectorAll('[data-key]').forEach(function(el){
      var key = el.getAttribute('data-key');
      if(el.type === 'checkbox') el.checked = !!state[key];
      else el.value = state[key];
    });
    document.getElementById('colorPicker').value = String(state.color || '#FFFFFF').toLowerCase();

    document.querySelectorAll('[data-style]').forEach(function(el){
      el.classList.toggle('is-active', el.getAttribute('data-style') === state.style);
    });
    document.querySelectorAll('[data-color]').forEach(function(el){
      el.classList.toggle('is-active', el.getAttribute('data-color').toUpperCase() === state.color.toUpperCase());
    });
  }

  function render(){
    setControls();

    document.getElementById('sizeOut').textContent = state.size;
    document.getElementById('thicknessOut').textContent = state.thickness;
    document.getElementById('gapOut').textContent = state.gap;
    document.getElementById('opacityOut').textContent = Math.round((state.opacity / 255) * 100) + '%';
    document.getElementById('offsetXOut').textContent = (state.offsetX > 0 ? '+' : '') + state.offsetX;
    document.getElementById('offsetYOut').textContent = (state.offsetY > 0 ? '+' : '') + state.offsetY;

    var names = {dot:'PONTO', classic:'CLÁSSICA', plus:'CRUZ', x:'X'};
    document.getElementById('styleName').textContent = names[state.style] || 'PONTO';

    var root = document.getElementById('previewCrosshair');
    var alpha = Math.max(.15, state.opacity / 255);
    var shadow = state.outline ? '0 0 0 1px rgba(0,0,0,.85), 0 0 8px rgba(0,0,0,.28)' : 'none';
    root.style.setProperty('--cross', state.color);
    root.style.setProperty('--alpha', alpha);
    root.style.setProperty('--shadow', shadow);
    root.style.transform = 'translate(' + (state.offsetX * .22) + 'px,' + (state.offsetY * .22) + 'px)';
    root.innerHTML = '';

    var size = Math.max(2, Number(state.size));
    var thick = Math.max(1, Number(state.thickness));
    var gap = Math.max(0, Number(state.gap));

    if(state.style === 'dot'){
      var d = document.createElement('i');
      d.className = 'pc-dot';
      d.style.width = size + 'px';
      d.style.height = size + 'px';
      root.appendChild(d);
    }else if(state.style === 'classic'){
      [
        ['pc-h-left', -(gap + size), -thick/2, size, thick],
        ['pc-h-right', gap, -thick/2, size, thick],
        ['pc-v-top', -thick/2, -(gap + size), thick, size],
        ['pc-v-bottom', -thick/2, gap, thick, size]
      ].forEach(function(v){
        var e = document.createElement('i');
        e.className = v[0];
        e.style.left = v[1] + 'px'; e.style.top = v[2] + 'px';
        e.style.width = v[3] + 'px'; e.style.height = v[4] + 'px';
        root.appendChild(e);
      });
    }else if(state.style === 'plus'){
      var h = document.createElement('i'), v = document.createElement('i');
      h.className='pc-bar'; v.className='pc-bar';
      h.style.left=(-size)+'px'; h.style.top=(-thick/2)+'px'; h.style.width=(size*2)+'px'; h.style.height=thick+'px';
      v.style.left=(-thick/2)+'px'; v.style.top=(-size)+'px'; v.style.width=thick+'px'; v.style.height=(size*2)+'px';
      root.appendChild(h); root.appendChild(v);
    }else{
      var a = document.createElement('i'), b = document.createElement('i');
      a.className='pc-x'; b.className='pc-x';
      [a,b].forEach(function(e){e.style.width=(size*2.8)+'px';e.style.height=thick+'px';e.style.left=(-size*1.4)+'px';e.style.top=(-thick/2)+'px';});
      a.style.transform='rotate(45deg)'; b.style.transform='rotate(-45deg)';
      root.appendChild(a); root.appendChild(b);
    }
  }

  document.querySelectorAll('input[type=range][data-key]').forEach(function(el){
    el.addEventListener('input', function(){ num(el.getAttribute('data-key'), el.value); });
  });

  document.querySelectorAll('input[type=checkbox][data-key]').forEach(function(el){
    el.addEventListener('change', function(){
      state[el.getAttribute('data-key')] = el.checked;
      live();
    });
  });

  document.querySelectorAll('[data-style]').forEach(function(el){
    el.addEventListener('click', function(){
      state.style = el.getAttribute('data-style');
      live();
    });
  });

  document.querySelectorAll('[data-color]').forEach(function(el){
    var c = el.getAttribute('data-color');
    el.style.setProperty('--swatch', c);
    el.addEventListener('click', function(){
      state.color = c.toUpperCase();
      live();
    });
  });

  document.getElementById('colorPicker').addEventListener('input', function(e){
    state.color = String(e.target.value).toUpperCase();
    live();
  });

  document.getElementById('resetBtn').addEventListener('click', function(){
    state = Object.assign({}, defaults);
    render();
    lua('reset', state);
  });

  document.getElementById('saveBtn').addEventListener('click', function(){
    lua('save', state);
  });

  document.getElementById('closeBtn').addEventListener('click', function(){
    lua('close', {});
  });

  document.addEventListener('keydown', function(e){
    if(e.key === 'Escape') lua('close', {});
  });

  window.crosshairSet = function(payload){
    if(Array.isArray(payload)) payload = payload[0] || {};
    state = Object.assign({}, defaults, payload || {});
    render();
  };

  render();
})();
