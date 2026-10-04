(() => {
  'use strict';

  const states = {
    idle: {
      label: 'Ready when you are',
      kicker: 'Immediate acknowledgement',
      title: 'Ready before the thought moves on.',
      copy: 'The capsule appears close to the bottom edge, above the active app, without taking keyboard focus. The response is immediate so the shortcut feels connected to the result.'
    },
    listening: {
      label: 'Listening',
      kicker: 'Real audio feedback',
      title: 'The signal follows the voice.',
      copy: 'Live microphone levels shape the mint bars every 50 milliseconds. The movement confirms that recording is active and that sound is reaching the selected input.'
    },
    processing: {
      label: 'Transcribing',
      kicker: 'Fast directional motion',
      title: 'Motion makes the wait feel active.',
      copy: 'The waveform becomes quick directional traces in 140 milliseconds. The repeating pattern communicates work without inventing a progress percentage.'
    },
    pasted: {
      label: 'Words inserted',
      kicker: 'Completion after success',
      title: 'Confirmation arrives with the text.',
      copy: 'The finished state appears only after the transcript reaches the original app. That timing keeps the visual promise aligned with the actual result.'
    }
  };

  const tabs = [...document.querySelectorAll('[data-design-state]')];
  const capsule = document.querySelector('.design-capsule');
  const label = document.getElementById('design-capsule-label');
  const kicker = document.getElementById('design-state-kicker');
  const title = document.getElementById('design-state-title');
  const copy = document.getElementById('design-state-copy');

  document.querySelectorAll('.design-capsule .capsule-signal i').forEach((bar, index) => bar.style.setProperty('--bar-index', index));

  function selectState(name) {
    const state = states[name];
    if (!state || !capsule) return;
    capsule.dataset.state = name;
    capsule.setAttribute('aria-label', `${state.label} capsule preview`);
    label.textContent = state.label;
    kicker.textContent = state.kicker;
    title.textContent = state.title;
    copy.textContent = state.copy;
    tabs.forEach(tab => {
      const selected = tab.dataset.designState === name;
      tab.classList.toggle('is-selected', selected);
      tab.setAttribute('aria-selected', String(selected));
      tab.tabIndex = selected ? 0 : -1;
    });
  }

  tabs.forEach((tab, index) => {
    tab.addEventListener('click', () => selectState(tab.dataset.designState));
    tab.addEventListener('keydown', event => {
      if (!['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown'].includes(event.key)) return;
      event.preventDefault();
      const direction = ['ArrowRight', 'ArrowDown'].includes(event.key) ? 1 : -1;
      const next = tabs[(index + direction + tabs.length) % tabs.length];
      next.focus();
      selectState(next.dataset.designState);
    });
  });
})();
