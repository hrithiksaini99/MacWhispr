(() => {
  'use strict';

  const repository = 'https://github.com/hrithiksaini99/MacWhispr/blob/main/';
  const components = {
    orchestrator: {
      layer: 'Application layer', title: 'AppDelegate is the coordinator.',
      purpose: 'It owns the complete dictation state machine, connects every callback, remembers the previously active app, and keeps exactly one transcription task alive.',
      apis: 'NSApplication, NSWorkspace, UserNotifications, Carbon', input: 'Hot key events, menu actions, audio levels, model choices', output: 'Recording, transcribing, pasted, and failure transitions',
      guardrail: 'Separate recording and busy flags prevent overlapping capture and inference.', code: 'hot key → start recording\nhot key → stop recording\nTask → transcribe → reactivate app → paste',
      file: 'Sources/MacWhispr/main.swift', sourceLabel: 'Open main.swift'
    },
    menu: {
      layer: 'Control surface', title: 'MenuBarController rebuilds from current state.',
      purpose: 'A single NSStatusItem exposes recording, activation mode, shortcut, input device, model downloads, permission status, model storage, and quit behavior.',
      apis: 'NSStatusItem, NSMenu, NSMenuDelegate, AVFoundation', input: 'Recording flag, download progress, selected settings, permissions', output: 'Typed callbacks to the application coordinator',
      guardrail: 'Actions that conflict with recording, transcription, or download are disabled while that work is active.', code: 'state changes → refresh menu\nmenu item → typed callback\ncoordinator → perform side effect',
      file: 'Sources/MacWhispr/MenuBarController.swift', sourceLabel: 'Open MenuBarController.swift'
    },
    shortcut: {
      layer: 'Global input', title: 'The shortcut is captured, registered, then saved.',
      purpose: 'A focused AppKit panel converts NSEvent key data into Carbon key codes and modifier flags. The global handler receives both press and release for Toggle and Push to Talk.',
      apis: 'NSEvent, RegisterEventHotKey, InstallEventHandler, UserDefaults', input: 'Key code plus Command, Option, or Control modifiers', output: 'Global pressed and released events with a stable hot key ID',
      guardrail: 'Bare keys and Shift only combinations are rejected. A conflicting shortcut never replaces the last working one.', code: 'unregister current shortcut\ncapture NSEvent\nregister candidate\npersist only after success',
      file: 'Sources/MacWhispr/Models/HotKeyShortcut.swift', sourceLabel: 'Open HotKeyShortcut.swift'
    },
    audio: {
      layer: 'Audio capture', title: 'DictationService creates inference ready audio.',
      purpose: 'The selected Core Audio input becomes the system default, then AVAudioRecorder writes a temporary WAV while metering supplies real values to the capsule.',
      apis: 'AVAudioRecorder, AVCaptureDevice, Core Audio, Timer', input: 'Preferred device UID and microphone permission', output: 'Temporary 16 kHz mono 16 bit PCM WAV plus peak decibels',
      guardrail: 'An unavailable device stops capture. A peak below minus 50 dB rejects silence before starting the engine.', code: 'apply preferred input\nrecord PCM WAV\nevery 50 ms → update meter\nstop → return URL and peak',
      file: 'Sources/MacWhispr/DictationService.swift', sourceLabel: 'Open DictationService.swift'
    },
    models: {
      layer: 'Model storage', title: 'ModelManager installs only validated GGML files.',
      purpose: 'It owns the model catalog, selected model preference, download progress, local storage path, and validation before a temporary download becomes the active file.',
      apis: 'URLSession, FileManager, UserDefaults', input: 'Selected WhisperModel and Hugging Face response', output: 'Validated GGML file in Application Support',
      guardrail: 'The file must exceed 80 percent of catalog size, match expected content length, and begin with the GGML magic bytes.', code: 'download to temporary URL\nvalidate status, size, magic\nmove into models directory\nvalidate installed file again',
      file: 'Sources/MacWhispr/ModelManager.swift', sourceLabel: 'Open ModelManager.swift'
    },
    transcriber: {
      layer: 'Inference boundary', title: 'Transcriber treats whisper.cpp as an owned process.',
      purpose: 'It finds the bundled engine before development fallbacks, builds arguments from audio and model paths, runs off the main actor, and returns trimmed stdout.',
      apis: 'Process, Task.detached, DispatchSourceTimer, POSIX signals', input: 'WAV URL, validated model URL, language policy', output: 'Transcript string or a bounded diagnostic error',
      guardrail: 'Private disk backed output avoids pipe deadlock. Timeout and cancellation terminate, then send SIGKILL after two seconds if needed.', code: 'timeout = clamp(audio seconds × 20 + 60)\nlaunch process with private output files\nwait or cancel\nreturn stdout; retain at most 16 KB stderr',
      file: 'Sources/MacWhispr/Transcriber.swift', sourceLabel: 'Open Transcriber.swift'
    },
    capsule: {
      layer: 'Feedback interface', title: 'The capsule stays visible without taking focus.',
      purpose: 'An AppKit nonactivating NSPanel hosts a SwiftUI view. Observable state drives phase, meter level, shortcut copy, Reduce Motion, and timed dismissal.',
      apis: 'NSPanel, NSHostingView, SwiftUI Canvas, TimelineView', input: 'Capsule phase, microphone decibels, accessibility display settings', output: 'Listening waveform, transcription activity, success, or failure feedback',
      guardrail: 'The panel cannot become key or main, joins every Space, and follows the screen where recording began.', code: 'NSPanel never becomes key\nstate publishes phase and level\nCanvas draws at display cadence\ncompletion dismisses after 850 ms',
      file: 'Sources/MacWhispr/Support/DictationCapsuleController.swift', sourceLabel: 'Open DictationCapsuleController.swift'
    },
    paste: {
      layer: 'System integration', title: 'PasteService returns the transcript to its origin.',
      purpose: 'The coordinator saves the frontmost application before capture. After inference it reactivates that app, places text on NSPasteboard, and emits Command V.',
      apis: 'NSRunningApplication, NSPasteboard, AXIsProcessTrusted, CGEvent', input: 'Transcript string and previously active application', output: 'Text in the destination field, with a clipboard fallback',
      guardrail: 'Accessibility is checked before synthetic input. When paste is blocked, the transcript remains available for manual Command V.', code: 'save frontmost app before recording\nreactivate after transcription\nwait 120 ms\ncopy text → emit Command V',
      file: 'Sources/MacWhispr/DictationService.swift', sourceLabel: 'Open PasteService'
    },
    release: {
      layer: 'Distribution', title: 'The release script builds a self contained app.',
      purpose: 'SwiftPM produces the executable. The packager adds Info.plist, icon, licenses, and the pinned static whisper.cpp helper before signing and archiving.',
      apis: 'SwiftPM, codesign, notarytool, stapler, Gatekeeper', input: 'Release executable, arm64 speech helper, assets, signing identity', output: 'Versioned ZIP plus SHA 256 checksum',
      guardrail: 'The helper must link only Apple system libraries and target macOS 13 or earlier. The helper is signed before the containing app.', code: 'verify helper dependencies and minimum OS\nbuild release executable\nassemble app bundle\nsign → notarize → staple → assess',
      file: 'script/package_release.sh', sourceLabel: 'Open package_release.sh'
    }
  };

  const nodes = [...document.querySelectorAll('[data-component]')];
  const fields = {
    layer: document.getElementById('component-layer'), title: document.getElementById('component-title'), purpose: document.getElementById('component-purpose'),
    apis: document.getElementById('component-apis'), input: document.getElementById('component-input'), output: document.getElementById('component-output'),
    guardrail: document.getElementById('component-guardrail'), code: document.getElementById('component-code'), source: document.getElementById('component-source')
  };

  function selectComponent(name) {
    const component = components[name];
    if (!component) return;
    Object.entries(fields).forEach(([key, element]) => {
      if (!element || key === 'source') return;
      element.textContent = component[key];
    });
    fields.source.href = repository + component.file;
    fields.source.firstChild.textContent = component.sourceLabel + ' ';
    nodes.forEach(node => {
      const selected = node.dataset.component === name;
      node.classList.toggle('is-selected', selected);
      node.setAttribute('aria-selected', String(selected));
      node.tabIndex = selected ? 0 : -1;
    });
  }

  nodes.forEach((node, index) => {
    node.addEventListener('click', () => selectComponent(node.dataset.component));
    node.addEventListener('keydown', event => {
      if (!['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown'].includes(event.key)) return;
      event.preventDefault();
      const direction = ['ArrowRight', 'ArrowDown'].includes(event.key) ? 1 : -1;
      const next = nodes[(index + direction + nodes.length) % nodes.length];
      next.focus();
      selectComponent(next.dataset.component);
    });
  });
})();
