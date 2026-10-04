(() => {
  'use strict';
  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
  document.documentElement.classList.add('js');

  const revealObserver = new IntersectionObserver(entries => {
    entries.forEach(entry => {
      if (!entry.isIntersecting) return;
      entry.target.classList.add('is-visible');
      revealObserver.unobserve(entry.target);
    });
  }, { threshold: 0.08 });
  document.querySelectorAll('.reveal').forEach(el => revealObserver.observe(el));

  const words = document.querySelectorAll('.word-reveal span');
  const wordObserver = new IntersectionObserver(entries => {
    entries.forEach(entry => {
      if (!entry.isIntersecting) return;
      const delay = reducedMotion.matches ? 0 : Number(entry.target.dataset.wordIndex) * 90;
      window.setTimeout(() => entry.target.classList.add('is-active'), delay);
      wordObserver.unobserve(entry.target);
    });
  }, { rootMargin: '0px 0px -25% 0px', threshold: 1 });
  words.forEach((word, index) => { word.dataset.wordIndex = index; wordObserver.observe(word); });

  const toggle = document.querySelector('.menu-toggle');
  const dialog = document.querySelector('.menu-dialog');
  let closeTimer;
  let previouslyFocused;
  const menuLinks = dialog ? [...dialog.querySelectorAll('a')] : [];
  menuLinks.forEach((link, index) => link.style.setProperty('--menu-index', index));
  function closeMenu(restoreFocus = true) {
    if (!dialog || toggle.getAttribute('aria-expanded') !== 'true') return;
    toggle.setAttribute('aria-expanded', 'false');
    toggle.setAttribute('aria-label', 'Open navigation');
    dialog.classList.remove('is-open');
    document.body.classList.remove('menu-open');
    document.querySelector('main').inert = false;
    document.querySelector('footer').inert = false;
    dialog.inert = true;
    closeTimer = window.setTimeout(() => { dialog.hidden = true; }, reducedMotion.matches ? 0 : 700);
    if (restoreFocus) (previouslyFocused || toggle).focus();
  }
  function openMenu() {
    window.clearTimeout(closeTimer);
    previouslyFocused = document.activeElement;
    dialog.hidden = false;
    dialog.inert = false;
    toggle.setAttribute('aria-expanded', 'true');
    toggle.setAttribute('aria-label', 'Close navigation');
    document.body.classList.add('menu-open');
    document.querySelector('main').inert = true;
    document.querySelector('footer').inert = true;
    window.requestAnimationFrame(() => { dialog.classList.add('is-open'); menuLinks[0]?.focus(); });
  }
  toggle?.addEventListener('click', () => toggle.getAttribute('aria-expanded') === 'true' ? closeMenu() : openMenu());
  menuLinks.forEach(link => link.addEventListener('click', () => closeMenu()));
  document.addEventListener('keydown', event => {
    if (!dialog || toggle.getAttribute('aria-expanded') !== 'true') return;
    if (event.key === 'Escape') { event.preventDefault(); closeMenu(); }
    if (event.key === 'Tab') {
      const focusables = [toggle, ...menuLinks];
      const index = focusables.indexOf(document.activeElement);
      const next = event.shiftKey ? (index <= 0 ? focusables.length - 1 : index - 1) : (index >= focusables.length - 1 ? 0 : index + 1);
      event.preventDefault(); focusables[next].focus();
    }
  });
  window.matchMedia('(min-width: 801px)').addEventListener('change', event => { if (event.matches) closeMenu(false); });

  const play = document.getElementById('demo-play');
  const capsule = document.querySelector('.demo-capsule');
  const label = document.getElementById('capsule-status');
  const text = document.getElementById('demo-text');
  const status = document.getElementById('demo-status');
  const hint = document.getElementById('demo-hint');
  const initialText = 'The best ideas rarely arrive at a desk.\nGive them a little room.';
  const resultText = 'The best ideas rarely arrive at a desk.\nGive them a little room.\nAnd a voice of their own.';
  let demoRunning = false;
  document.querySelectorAll('.capsule-signal i').forEach((bar, index) => bar.style.setProperty('--bar-index', index));
  const pause = duration => new Promise(resolve => window.setTimeout(resolve, duration));
  play?.addEventListener('click', async () => {
    if (demoRunning) return;
    demoRunning = true;
    play.disabled = true;
    play.firstChild.textContent = 'Playing the demo';
    text.textContent = initialText;
    capsule.dataset.state = 'listening'; label.textContent = 'Listening';
    hint.textContent = 'The capsule responds while you speak.';
    status.textContent = 'Demo: listening. No audio is being recorded.';
    await pause(reducedMotion.matches ? 800 : 1800);
    capsule.dataset.state = 'processing'; label.textContent = 'Transcribing';
    hint.textContent = 'Your selected model works locally.';
    status.textContent = 'Demo: local transcription. This is an illustrative sequence.';
    await pause(reducedMotion.matches ? 800 : 1200);
    text.textContent = resultText;
    capsule.dataset.state = 'pasted'; label.textContent = 'Words inserted';
    hint.textContent = 'Back to your thought.';
    status.textContent = 'Demo complete. In the app, text is pasted after transcription finishes.';
    play.disabled = false;
    play.firstChild.textContent = 'Play it again';
    demoRunning = false;
  });
})();
