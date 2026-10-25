// ==========================================================================
// sane-deck WebSocket Client & M3 Controller (Pixel + Agy v5)
// ==========================================================================

(function() {
  'use strict';

  const CIRCUMFERENCE = 251.33; // 2 * PI * 40
  let ws = null;
  let isDraggingMaster = false;
  let draggingStreamName = null;
  let lastSliderSend = 0;

  // DOM Elements
  const connDot = document.getElementById('conn-dot');
  const btnFullscreen = document.getElementById('btn-fullscreen');
  const focusedAppTitle = document.getElementById('focused-app-title');

  // Top Agy Chip
  const topAgyChip = document.getElementById('top-agy-chip');
  const topAgyVal = document.getElementById('top-agy-val');

  // Pixel Gauges
  const ringCpu = document.getElementById('ring-cpu');
  const valCpu = document.getElementById('val-cpu');
  const subCpu = document.getElementById('sub-cpu');

  const ringRam = document.getElementById('ring-ram');
  const valRam = document.getElementById('val-ram');
  const subRam = document.getElementById('sub-ram');

  const ringGpu = document.getElementById('ring-gpu');
  const valGpu = document.getElementById('val-gpu');
  const subGpu = document.getElementById('sub-gpu');

  const ringPhone = document.getElementById('ring-phone');
  const valPhone = document.getElementById('val-phone');
  const subPhone = document.getElementById('sub-phone');
  const phoneCenterWrapper = document.getElementById('phone-center-wrapper');

  // Antigravity (Agy) Elements
  const agyCard = document.getElementById('agy-card');
  const agyStatusBadge = document.getElementById('agy-status-badge');
  const agyTaskTitle = document.getElementById('agy-task-title');
  const agyMainLabel = document.getElementById('agy-main-label');
  const agyMainVal = document.getElementById('agy-main-val');
  const agyMainFill = document.getElementById('agy-main-fill');
  const agyMainReset = document.getElementById('agy-main-reset');
  const agyBucketsContainer = document.getElementById('agy-buckets-container');
  const btnRefreshAgy = document.getElementById('btn-refresh-agy');

  // Audio & Mixer
  const masterVolVal = document.getElementById('master-vol-val');
  const masterSliderTrack = document.getElementById('master-slider-track');
  const masterSliderFill = document.getElementById('master-slider-fill');
  const masterSliderThumb = document.getElementById('master-slider-thumb');

  const micToggleBtn = document.getElementById('mic-toggle-btn');
  const micStatusLabel = document.getElementById('mic-status-label');
  const streamsContainer = document.getElementById('streams-container');

  const sinkAnalog = document.getElementById('sink-analog');
  const sinkHdmi = document.getElementById('sink-hdmi');

  // Workspaces
  const workspacesDvi = document.getElementById('workspaces-dvi');
  const workspacesHdmi = document.getElementById('workspaces-hdmi');

  // Media
  const mediaTitle = document.getElementById('media-title');
  const mediaStatus = document.getElementById('media-status');
  const playPauseIcon = document.getElementById('play-pause-icon');

  // --- Helper to update Pixel circular rings ---
  function updateRing(element, percent) {
    if (!element) return;
    const p = Math.max(0, Math.min(100, percent));
    const offset = CIRCUMFERENCE * (1 - p / 100);
    element.style.strokeDashoffset = offset;
  }

  // --- Screen Wake Lock ---
  async function requestWakeLock() {
    try {
      if ('wakeLock' in navigator) {
        await navigator.wakeLock.request('screen');
      }
    } catch (_) {}
  }
  requestWakeLock();
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible') requestWakeLock();
  });

  // --- Fullscreen Toggle ---
  if (btnFullscreen) {
    btnFullscreen.addEventListener('click', () => {
      if (!document.fullscreenElement) {
        document.documentElement.requestFullscreen().catch(() => {});
      } else {
        document.exitFullscreen().catch(() => {});
      }
    });
  }

  // --- Scroll to Agy card ---
  if (topAgyChip && agyCard) {
    topAgyChip.addEventListener('click', () => {
      agyCard.scrollIntoView({ behavior: 'smooth' });
    });
  }

  // --- WebSocket Connection ---
  function connect() {
    const proto = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const wsUrl = `${proto}//${window.location.host}/ws`;

    ws = new WebSocket(wsUrl);

    ws.onopen = function() {
      if (connDot) connDot.classList.add('connected');
    };

    ws.onclose = function() {
      if (connDot) connDot.classList.remove('connected');
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
    if (!state) return;

    // 1. Pixel Battery-Style Telemetry & Hardware Gauges
    if (state.telemetry) {
      // CPU Gauge
      if (valCpu) valCpu.textContent = `${state.telemetry.cpu}%`;
      if (subCpu) {
        const cTemp = state.telemetry.cpu_temp || 42;
        subCpu.textContent = `CPU • ${cTemp}°C`;
      }
      updateRing(ringCpu, state.telemetry.cpu);

      // RAM Gauge
      const ramPct = state.telemetry.ram_percent || 40;
      if (valRam) valRam.textContent = `${ramPct}%`;
      if (subRam) subRam.textContent = `RAM • ${state.telemetry.ram || '6.4 GB'}`;
      updateRing(ringRam, ramPct);

      // GPU Gauge (Temperature based percentage, 85°C max scale)
      const gpuTemp = state.telemetry.gpu || 43;
      if (valGpu) valGpu.textContent = `${gpuTemp}°C`;
      if (subGpu) subGpu.textContent = `GPU • Radeon`;
      const gpuPct = Math.round((gpuTemp / 85) * 100);
      updateRing(ringGpu, gpuPct);

      // Focused App Badge
      if (focusedAppTitle && state.telemetry.focused_app) {
        focusedAppTitle.textContent = state.telemetry.focused_app;
      }
    }

    // Phone Battery Gauge (Pixel Style)
    if (state.phone) {
      const bLvl = state.phone.battery || 76;
      if (valPhone) valPhone.textContent = `${bLvl}%`;
      if (subPhone) {
        subPhone.textContent = state.phone.charging ? 'Mate 20 • ⚡' : 'Mate 20 • USB';
      }
      updateRing(ringPhone, bLvl);

      if (phoneCenterWrapper) {
        if (state.phone.charging) {
          phoneCenterWrapper.innerHTML = '<svg class="gauge-icon" viewBox="0 0 24 24"><path d="M7 2v11h3v9l7-12h-4l4-8z"/></svg>'; // Lightning bolt
        } else {
          phoneCenterWrapper.innerHTML = '<svg class="gauge-icon" viewBox="0 0 24 24"><path d="M17 1.01L7 1c-1.1 0-2 .9-2 2v18c0 1.1.9 2 2 2h10c1.1 0 2-.9 2-2V3c0-1.1-.9-1.99-2-1.99zM17 19H7V5h10v14z"/></svg>'; // Phone
        }
      }
    }

    // 2. Google Antigravity (Agy) Status & Quota
    if (state.agy) {
      const agyPct = state.agy.primaryPercentage || 100;
      if (topAgyVal) topAgyVal.textContent = `${agyPct}%`;
      if (topAgyChip) {
        if (state.agy.busy) topAgyChip.classList.add('busy');
        else topAgyChip.classList.remove('busy');
      }

      if (agyStatusBadge) {
        if (state.agy.busy) {
          agyStatusBadge.classList.add('busy');
          agyStatusBadge.textContent = 'Ocupado ⚡';
        } else {
          agyStatusBadge.classList.remove('busy');
          agyStatusBadge.textContent = 'Listo ✓';
        }
      }

      if (agyTaskTitle) {
        agyTaskTitle.textContent = state.agy.currentTask || 'En espera';
      }

      if (agyMainLabel) agyMainLabel.textContent = state.agy.primaryLabel || 'Límite 5h';
      if (agyMainVal) agyMainVal.textContent = `${agyPct}%`;
      if (agyMainFill) agyMainFill.style.width = `${agyPct}%`;
      if (agyMainReset) agyMainReset.textContent = `Reinicio en ${state.agy.primaryResetIn || '--'}`;

      // Render Sub-buckets
      renderAgyBuckets(state.agy.groups || []);
    }

    // 3. Audio Master, Sinks & Mic
    if (state.audio) {
      if (!isDraggingMaster && state.audio.master_vol !== undefined) {
        const pct = Math.round(state.audio.master_vol * 100);
        if (masterVolVal) masterVolVal.textContent = `${pct}%`;
        if (masterSliderFill) masterSliderFill.style.width = `${pct}%`;
        if (masterSliderThumb) masterSliderThumb.style.left = `${pct}%`;
      }

      if (state.audio.mic_muted !== undefined && micToggleBtn && micStatusLabel) {
        if (state.audio.mic_muted) {
          micToggleBtn.classList.add('muted');
          micStatusLabel.textContent = 'Muteado';
        } else {
          micToggleBtn.classList.remove('muted');
          micStatusLabel.textContent = 'Mic Activo';
        }
      }

      // Default sink indication
      if (state.audio.default_sink && sinkAnalog && sinkHdmi) {
        if (state.audio.default_sink === '57') {
          sinkAnalog.classList.add('active');
          sinkHdmi.classList.remove('active');
        } else if (state.audio.default_sink === '53') {
          sinkHdmi.classList.add('active');
          sinkAnalog.classList.remove('active');
        }
      }

      // Grouped Dynamic Streams
      renderStreams(state.audio.streams || []);
    }

    // 4. Workspaces (Pre-sorted by backend)
    if (state.workspaces) {
      if (workspacesDvi) renderWorkspaces(workspacesDvi, state.workspaces.dvi || []);
      if (workspacesHdmi) renderWorkspaces(workspacesHdmi, state.workspaces.hdmi || []);
    }

    // 5. Media
    if (state.media) {
      if (mediaTitle) mediaTitle.textContent = state.media.title || 'Sin reproducción activa';
      if (mediaStatus) mediaStatus.textContent = state.media.status || 'Inactivo';
      if (playPauseIcon) {
        if (state.media.status === 'Playing') {
          playPauseIcon.innerHTML = '<path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z"/>'; // Pause icon
        } else {
          playPauseIcon.innerHTML = '<path d="M8 5v14l11-7z"/>'; // Play icon
        }
      }
    }
  }

  // --- Render Agy Sub-Buckets ---
  function renderAgyBuckets(groups) {
    if (!agyBucketsContainer) return;
    agyBucketsContainer.innerHTML = '';

    groups.forEach(g => {
      if (!g.buckets) return;
      g.buckets.forEach(b => {
        const card = document.createElement('div');
        card.className = 'agy-bucket-card';

        const header = document.createElement('div');
        header.className = 'agy-bucket-header';

        const nameSpan = document.createElement('span');
        let shortName = b.displayName.replace(' Limit Remaining', '').replace(' Remaining', '');
        if (g.displayName.includes('Zen')) shortName = 'Zen ' + shortName;
        nameSpan.textContent = shortName;

        const pctSpan = document.createElement('span');
        pctSpan.className = 'agy-bucket-pct';
        pctSpan.textContent = `${b.percentage}%`;

        header.appendChild(nameSpan);
        header.appendChild(pctSpan);

        const bar = document.createElement('div');
        bar.className = 'agy-bucket-bar';

        const fill = document.createElement('div');
        fill.className = 'agy-bucket-fill';
        fill.style.width = `${b.percentage}%`;
        bar.appendChild(fill);

        const resetSpan = document.createElement('span');
        resetSpan.className = 'agy-bucket-reset';
        resetSpan.textContent = b.resetIn ? `Reset: ${b.resetIn}` : '';

        card.appendChild(header);
        card.appendChild(bar);
        card.appendChild(resetSpan);

        agyBucketsContainer.appendChild(card);
      });
    });
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
        sendCommand('focus-workspace', { output: wsItem.output, idx: wsItem.idx });
      };
      container.appendChild(chip);
    });
  }

  // --- Audio Streams Renderer (Grouped by App Name) ---
  function renderStreams(streams) {
    if (draggingStreamName !== null || !streamsContainer) return;
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

      setupSliderEvents(track, fill, thumb, val, (newPct) => {
        sendCommand('set-stream-volume', { name: stream.name, volume: newPct / 100 });
      }, () => {
        draggingStreamName = stream.name;
      }, () => {
        draggingStreamName = null;
      });

      row.appendChild(info);
      row.appendChild(track);
      streamsContainer.appendChild(row);
    });
  }

  // --- Generic Slider Drag Logic with Safety Check ---
  function setupSliderEvents(track, fill, thumb, label, onUpdate, onStart, onEnd) {
    if (!track || !fill || !thumb || !label) return;

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
      if (now - lastSliderSend > 30) {
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
  if (micToggleBtn) {
    micToggleBtn.addEventListener('click', () => {
      sendCommand('toggle-mic');
    });
  }

  // --- Refresh Agy Quota ---
  if (btnRefreshAgy) {
    btnRefreshAgy.addEventListener('click', () => {
      sendCommand('refresh-agy');
    });
  }

  // --- Audio Sink Switchers ---
  document.querySelectorAll('[data-sink]').forEach(btn => {
    btn.addEventListener('click', () => {
      const sinkId = btn.dataset.sink;
      sendCommand('set-default-sink', { id: sinkId });
    });
  });

  // --- App Focus Launchers ---
  document.querySelectorAll('[data-focus]').forEach(btn => {
    btn.addEventListener('click', () => {
      const app = btn.dataset.focus;
      sendCommand('focus-app', { action: app });
    });
  });

  // --- Desktop Action Buttons ---
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
