// ==========================================================================
// sane-deck WebSocket Client & M3 Controller
// ==========================================================================

(function() {
  'use strict';

  let ws = null;
  let isDraggingMaster = false;
  let draggingStreamId = null;
  let lastSliderSend = 0;

  // DOM Elements
  const connDot = document.getElementById('conn-dot');
  const statRam = document.getElementById('stat-ram');
  const statCpu = document.getElementById('stat-cpu');
  const statGpu = document.getElementById('stat-gpu');
  const focusedAppTitle = document.getElementById('focused-app-title');

  const masterVolVal = document.getElementById('master-vol-val');
  const masterSliderTrack = document.getElementById('master-slider-track');
  const masterSliderFill = document.getElementById('master-slider-fill');
  const masterSliderThumb = document.getElementById('master-slider-thumb');

  const micToggleBtn = document.getElementById('mic-toggle-btn');
  const micStatusLabel = document.getElementById('mic-status-label');
  const streamsContainer = document.getElementById('streams-container');

  const workspacesDvi = document.getElementById('workspaces-dvi');
  const workspacesHdmi = document.getElementById('workspaces-hdmi');

  const mediaTitle = document.getElementById('media-title');
  const mediaStatus = document.getElementById('media-status');
  const playPauseIcon = document.getElementById('play-pause-icon');

  // --- WebSocket Connection ---
  function connect() {
    const proto = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const wsUrl = `${proto}//${window.location.host}/ws`;

    ws = new WebSocket(wsUrl);

    ws.onopen = function() {
      connDot.classList.add('connected');
    };

    ws.onclose = function() {
      connDot.classList.remove('connected');
      setTimeout(connect, 1500); // Reconnect loop
    };

    ws.onerror = function() {
      ws.close();
    };

    ws.onmessage = function(event) {
      try {
        const data = JSON.parse(event.data);
        handleServerUpdate(data);
      } catch (err) {
        console.error('Error parsing WS message', err);
      }
    };
  }

  function sendCommand(cmd, payload = {}) {
    if (ws && ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({ cmd, ...payload }));
    }
  }

  // --- State Handler ---
  function handleServerUpdate(state) {
    // 1. Telemetry
    if (state.telemetry) {
      if (state.telemetry.ram) statRam.textContent = state.telemetry.ram;
      if (state.telemetry.cpu !== undefined) statCpu.textContent = `${state.telemetry.cpu}%`;
      if (state.telemetry.gpu !== undefined) statGpu.textContent = `${state.telemetry.gpu}°C`;
      if (state.telemetry.focused_app) focusedAppTitle.textContent = state.telemetry.focused_app;
    }

    // 2. Audio Master & Mic
    if (state.audio) {
      if (!isDraggingMaster && state.audio.master_vol !== undefined) {
        const pct = Math.round(state.audio.master_vol * 100);
        masterVolVal.textContent = `${pct}%`;
        masterSliderFill.style.width = `${pct}%`;
        masterSliderThumb.style.left = `${pct}%`;
      }

      if (state.audio.mic_muted !== undefined) {
        if (state.audio.mic_muted) {
          micToggleBtn.classList.add('muted');
          micStatusLabel.textContent = 'Muteado';
        } else {
          micToggleBtn.classList.remove('muted');
          micStatusLabel.textContent = 'Mic Activo';
        }
      }

      // Dynamic Streams
      renderStreams(state.audio.streams || []);
    }

    // 3. Workspaces
    if (state.workspaces) {
      renderWorkspaces(workspacesDvi, state.workspaces.dvi || []);
      renderWorkspaces(workspacesHdmi, state.workspaces.hdmi || []);
    }

    // 4. Media
    if (state.media) {
      mediaTitle.textContent = state.media.title || 'Sin reproducción activa';
      mediaStatus.textContent = state.media.status || 'Inactivo';
      if (state.media.status === 'Playing') {
        playPauseIcon.innerHTML = '<path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z"/>'; // Pause icon
      } else {
        playPauseIcon.innerHTML = '<path d="M8 5v14l11-7z"/>'; // Play icon
      }
    }
  }

  // --- Workspaces Renderer ---
  function renderWorkspaces(container, list) {
    container.innerHTML = '';
    list.forEach(wsItem => {
      const chip = document.createElement('button');
      chip.className = 'm3-ws-chip';
      if (wsItem.is_focused) chip.classList.add('focused');
      else if (wsItem.is_active) chip.classList.add('active');

      chip.textContent = wsItem.idx;
      chip.onclick = () => {
        sendCommand('niri-action', { action: `focus-workspace ${wsItem.idx}` });
      };
      container.appendChild(chip);
    });
  }

  // --- Audio Streams Renderer ---
  function renderStreams(streams) {
    if (draggingStreamId !== null) return; // Don't redraw while user is dragging
    streamsContainer.innerHTML = '';

    streams.forEach(stream => {
      const row = document.createElement('div');
      row.className = 'slider-row';

      const info = document.createElement('div');
      info.className = 'slider-info';

      const label = document.createElement('span');
      label.className = 'slider-label';
      label.textContent = stream.name;

      const pctVal = Math.round(stream.volume * 100);
      const val = document.createElement('span');
      val.className = 'slider-value';
      val.textContent = `${pctVal}%`;

      info.appendChild(label);
      info.appendChild(val);

      const track = document.createElement('div');
      track.className = 'm3-slider-container';

      const fill = document.createElement('div');
      fill.className = 'm3-slider-fill';
      fill.style.width = `${pctVal}%`;

      const thumb = document.createElement('div');
      thumb.className = 'm3-slider-thumb';
      thumb.style.left = `${pctVal}%`;

      track.appendChild(fill);
      track.appendChild(thumb);

      // Attach Touch / Drag to dynamic slider
      setupSliderEvents(track, fill, thumb, val, (newPct) => {
        sendCommand('set-stream-volume', { id: stream.id, volume: newPct / 100 });
      }, () => {
        draggingStreamId = stream.id;
      }, () => {
        draggingStreamId = null;
      });

      row.appendChild(info);
      row.appendChild(track);
      streamsContainer.appendChild(row);
    });
  }

  // --- Generic Slider Drag Logic ---
  function setupSliderEvents(track, fill, thumb, label, onUpdate, onStart, onEnd) {
    function handleMove(e) {
      const rect = track.getBoundingClientRect();
      const clientX = e.touches ? e.touches[0].clientX : e.clientX;
      let pos = (clientX - rect.left) / rect.width;
      pos = Math.max(0, Math.min(1, pos));
      const pct = Math.round(pos * 100);

      fill.style.width = `${pct}%`;
      thumb.style.left = `${pct}%`;
      label.textContent = `${pct}%`;

      const now = Date.now();
      if (now - lastSliderSend > 35) { // 35ms throttle (~30 fps)
        lastSliderSend = now;
        onUpdate(pct);
      }
    }

    function startDrag(e) {
      e.preventDefault();
      if (onStart) onStart();
      handleMove(e);

      function moveListener(moveEvent) {
        handleMove(moveEvent);
      }

      function stopListener(stopEvent) {
        window.removeEventListener('mousemove', moveListener);
        window.removeEventListener('mouseup', stopListener);
        window.removeEventListener('touchmove', moveListener);
        window.removeEventListener('touchend', stopListener);
        if (onEnd) onEnd();
      }

      window.addEventListener('mousemove', moveListener);
      window.addEventListener('mouseup', stopListener);
      window.addEventListener('touchmove', moveListener, { passive: false });
      window.addEventListener('touchend', stopListener);
    }

    track.addEventListener('mousedown', startDrag);
    track.addEventListener('touchstart', startDrag, { passive: false });
  }

  // --- Initialize Master Slider ---
  setupSliderEvents(
    masterSliderTrack,
    masterSliderFill,
    masterSliderThumb,
    masterVolVal,
    (pct) => {
      sendCommand('set-master-volume', { volume: pct / 100 });
    },
    () => { isDraggingMaster = true; },
    () => { isDraggingMaster = false; }
  );

  // --- Mic Toggle ---
  micToggleBtn.addEventListener('click', () => {
    sendCommand('toggle-mic');
  });

  // --- Action Buttons ---
  document.querySelectorAll('.m3-action-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const action = btn.dataset.action;
      if (action) {
        sendCommand('niri-action', { action });
      }
    });
  });

  // --- Media Buttons ---
  document.querySelectorAll('.media-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const mediaCmd = btn.dataset.media;
      if (mediaCmd) {
        sendCommand('media-action', { action: mediaCmd });
      }
    });
  });

  // Start connection
  connect();
})();
