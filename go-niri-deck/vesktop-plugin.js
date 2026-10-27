// ============================================================================
// sane-deck Vesktop / Discord Integration Plugin
// ============================================================================
(async function initSaneDeckDiscord() {
  console.log("[sane-deck] Inicializando integración Vesktop <-> sane-deck...");
  try {
    await ra;
    console.log("[sane-deck] Webpack listo en Vesktop!");

    const SelectedChannelStore = tS.findStore("SelectedChannelStore");
    const ChannelStore = tS.findStore("ChannelStore");
    const GuildStore = tS.findStore("GuildStore");
    const MediaEngineStore = tS.findStore("MediaEngineStore");
    const FluxDispatcher = tS.Common?.FluxDispatcher || tS.findByProps("dispatch", "subscribe");
    const AudioActions = tS.findByProps("toggleSelfMute", "toggleSelfDeaf") || tS.findByProps("toggleSelfMute") || {};

    let ws = null;
    let reconnectTimer = null;

    function connectWS() {
      if (ws && (ws.readyState === WebSocket.OPEN || ws.readyState === WebSocket.CONNECTING)) return;
      try {
        ws = new WebSocket("ws://127.0.0.1:8080/ws");
      } catch (err) {
        reconnect();
        return;
      }

      ws.onopen = () => {
        console.log("[sane-deck] ¡Conectado al daemon go-niri-deck!");
        sendCurrentState();
      };

      ws.onmessage = (evt) => {
        try {
          const msg = JSON.parse(evt.data);
          handleDeckCommand(msg);
        } catch (e) {}
      };

      ws.onclose = () => {
        ws = null;
        reconnect();
      };

      ws.onerror = () => {
        if (ws) ws.close();
      };
    }

    function reconnect() {
      clearTimeout(reconnectTimer);
      reconnectTimer = setTimeout(connectWS, 2500);
    }

    function sendCurrentState() {
      if (!ws || ws.readyState !== WebSocket.OPEN) return;
      try {
        const voiceChannelId = SelectedChannelStore ? SelectedChannelStore.getVoiceChannelId() : null;
        const inVoice = !!voiceChannelId;
        let channelName = "";
        let guildName = "";

        if (inVoice && ChannelStore) {
          const channel = ChannelStore.getChannel(voiceChannelId);
          if (channel) {
            channelName = channel.name || "Canal de Voz";
            if (channel.guild_id && GuildStore) {
              const guild = GuildStore.getGuild(channel.guild_id);
              if (guild) guildName = guild.name || "";
            }
          }
        }

        const selfMute = MediaEngineStore 
          ? (typeof MediaEngineStore.isSelfMute === "function" ? MediaEngineStore.isSelfMute() : (MediaEngineStore.isMute?.() ?? false))
          : false;
        const selfDeaf = MediaEngineStore 
          ? (typeof MediaEngineStore.isSelfDeaf === "function" ? MediaEngineStore.isSelfDeaf() : (MediaEngineStore.isDeaf?.() ?? false))
          : false;

        const payload = {
          cmd: "discord_state_update",
          connected: true,
          in_voice: inVoice,
          channel: channelName,
          guild: guildName,
          self_mute: !!selfMute,
          self_deaf: !!selfDeaf
        };
        ws.send(JSON.stringify(payload));
      } catch (e) {
        console.error("[sane-deck] Error al enviar estado:", e);
      }
    }

    function handleDeckCommand(msg) {
      if (!msg || !msg.cmd) return;
      if (msg.cmd === "discord-toggle-mute") {
        if (AudioActions && typeof AudioActions.toggleSelfMute === "function") {
          AudioActions.toggleSelfMute();
        } else if (FluxDispatcher) {
          FluxDispatcher.dispatch({ type: "AUDIO_TOGGLE_SELF_MUTE" });
        }
        setTimeout(sendCurrentState, 50);
      } else if (msg.cmd === "discord-toggle-deaf") {
        if (AudioActions && typeof AudioActions.toggleSelfDeaf === "function") {
          AudioActions.toggleSelfDeaf();
        } else if (FluxDispatcher) {
          FluxDispatcher.dispatch({ type: "AUDIO_TOGGLE_SELF_DEAF" });
        }
        setTimeout(sendCurrentState, 50);
      } else if (msg.cmd === "discord-disconnect") {
        const selectVoice = tS.findByProps("selectVoiceChannel");
        if (selectVoice && typeof selectVoice.selectVoiceChannel === "function") {
          selectVoice.selectVoiceChannel(null);
        } else if (FluxDispatcher) {
          FluxDispatcher.dispatch({ type: "VOICE_CHANNEL_SELECT", channelId: null });
        }
      }
    }

    if (FluxDispatcher && typeof FluxDispatcher.subscribe === "function") {
      const events = [
        "AUDIO_TOGGLE_SELF_MUTE",
        "AUDIO_TOGGLE_SELF_DEAF",
        "AUDIO_SET_SELF_MUTE",
        "AUDIO_SET_SELF_DEAF",
        "VOICE_CHANNEL_SELECT",
        "VOICE_STATE_UPDATES"
      ];
      events.forEach((evtName) => {
        try {
          FluxDispatcher.subscribe(evtName, () => setTimeout(sendCurrentState, 50));
        } catch (e) {}
      });
    }

    setInterval(sendCurrentState, 2000);
    connectWS();
  } catch (err) {
    console.error("[sane-deck] Error inicializando:", err);
  }
})();
