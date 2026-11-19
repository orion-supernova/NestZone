// The duckling: one drawing in parts (body, head, wing, eye, beak), seven stages, four moods.
// The same idea as the plant's parts kit: the illustrator draws the parts once and code moves them.
(function () {
  const STAGES = ['Egg', 'Wobbly egg', 'Hatchling', 'Baby', 'Little one', 'Young', 'Grown'];
  const SCALE = [1, 1, .82, .62, .74, .86, 1];
  const MOODS = { bright: 'bright', content: 'content', sleepy: 'sleepy', dozing: 'dozing' };
  // Colour carries mood as much as the face does: a quiet house fades the yellow.
  const INK = {
    bright: { body: '#FFD13B', wing: '#F5B81C', blush: .95 },
    content: { body: '#FFD54A', wing: '#F4BE2A', blush: .6 },
    sleepy: { body: '#E8D48E', wing: '#D9BE6C', blush: .3 },
    dozing: { body: '#DCCB92', wing: '#CDB673', blush: .2 },
    waking: { body: '#FFD54A', wing: '#F4BE2A', blush: .6 },
  };

  function eyes(mood) {
    if (mood === 'sleepy' || mood === 'dozing')
      return '<path d="M38.5 47 q3.5 3.5 7 0" stroke="#2a1d0e" stroke-width="2" fill="none" stroke-linecap="round"/>';
    if (mood === 'bright')
      return '<g class="eye"><ellipse cx="42" cy="47" rx="3.8" ry="4.8" fill="#2a1d0e"/><circle cx="43.3" cy="45.2" r="1.6" fill="#fff"/><circle cx="40.6" cy="49" r=".8" fill="#fff"/></g>';
    return '<g class="eye"><ellipse cx="42" cy="47" rx="3.2" ry="4.2" fill="#2a1d0e"/><circle cx="43" cy="45.5" r="1.2" fill="#fff"/></g>';
  }

  function head(mood, ink) {
    const cap = mood === 'dozing' || mood === 'waking'
      ? '<g class="cap"><path d="M29 41 q14 -14 33 -3 q-1 -14 10 -20 q-17 -2 -25 7 q-10 4 -18 16 z" fill="#7C8BE8"/><path d="M29 41 q16 -8 33 -3" stroke="#fff" stroke-width="3" fill="none" stroke-linecap="round"/><circle cx="72" cy="18" r="4" fill="#fff"/></g>'
      : '';
    const tilt = mood === 'sleepy' || mood === 'dozing' ? 'transform="rotate(12 46 68)"' : '';
    return `<g class="head" ${tilt}><circle cx="46" cy="50" r="19" fill="${ink.body}"/><path d="M45 32 q3 -9 10 -4 q-6 0 -7 6 z" fill="${ink.wing}"/>
      <path d="M29 53 q-11 3 0 8 q8 1 9 -5 z" fill="#FF9F43"/>${eyes(mood)}<circle cx="51" cy="57" r="3.4" fill="#FF8FA3" opacity="${ink.blush}"/>${cap}</g>`;
  }

  function svg(stage, mood = 'content') {
    const ink = INK[mood] || INK.content, k = SCALE[stage];
    const sc = `transform="translate(60 108) scale(${k}) translate(-60 -108)"`;
    const shadow = `<ellipse cx="60" cy="108" rx="${stage < 2 ? 22 : 32 * k}" ry="${stage < 2 ? 5 : 5 * k + 1}" fill="rgba(0,0,0,.35)"/>`;
    if (stage < 2) {
      const crack = stage === 1 ? '<path d="M44 66 l6 5 l5 -6 l6 6 l6 -5" stroke="#d9c39a" stroke-width="2" fill="none" stroke-linejoin="round"/>' : '';
      const shell = mood === 'sleepy' || mood === 'dozing' ? '#EDE3CF' : '#FFF3DC';
      return `${shadow}<g class="eggg"><ellipse cx="60" cy="72" rx="24" ry="32" fill="${shell}"/><ellipse cx="51" cy="60" rx="6" ry="10" fill="#fff" opacity=".7"/>${crack}</g>`;
    }
    // The scale sits on its own group: a CSS animation on the same element would replace it.
    if (stage === 2)
      return `${shadow}<g class="wrap"><g class="bodyg"><g ${sc}><g transform="translate(14 34)">${head(mood, ink)}</g>
        <path d="M30 84 l7 -9 l7 8 l8 -10 l8 10 l8 -9 l7 8 l8 -9 l7 11 v12 a37 22 0 0 1 -60 0 z" fill="#FFF3DC"/></g></g></g>`;
    const slump = mood === 'sleepy' || mood === 'dozing' ? 'transform="translate(0 4) scale(1 .94)"' : '';
    const wingTilt = mood === 'sleepy' || mood === 'dozing' ? 'transform="rotate(14 66 78)"' : mood === 'bright' ? 'transform="rotate(-10 66 78)"' : '';
    const star = (x, y, r) => `<path d="M${x} ${y - r} Q${x} ${y} ${x + r} ${y} Q${x} ${y} ${x} ${y + r} Q${x} ${y} ${x - r} ${y} Q${x} ${y} ${x} ${y - r}z" fill="#FFE7A3"/>`;
    const glints = mood === 'bright' ? `<g class="sparks">${star(20, 40, 5)}${star(104, 52, 4)}${star(96, 22, 3)}</g>` : '';
    const grownBits = stage === 6 ? '<path d="M33 62 q13 8 26 0" stroke="#fff" stroke-width="3" fill="none" opacity=".85"/>' : '';
    return `${shadow}<g class="wrap"><g class="bodyg"><g ${sc}><g ${slump}>
      <ellipse cx="50" cy="105" rx="7" ry="3" fill="#FF9F43"/><ellipse cx="72" cy="105" rx="7" ry="3" fill="#FF9F43"/>
      <ellipse cx="62" cy="80" rx="30" ry="24" fill="${ink.body}"/><path d="M89 74 q8 -2 9 4 q-5 1 -9 2 z" fill="${ink.wing}"/>
      <g ${wingTilt}><ellipse class="wing" cx="70" cy="81" rx="14" ry="9" fill="${ink.wing}"/></g>${head(mood, ink)}${grownBits}</g></g></g></g>${glints}`;
  }

  // Draws a duck into an <svg> and keeps its classes in step: stage, mood, and the reactions.
  function mount(el, opts = {}) {
    const st = { stage: opts.stage ?? 5, mood: opts.mood ?? 'content', capOff: false };
    function draw() {
      el.setAttribute('class', `pet s${st.stage} ${st.mood}${st.capOff ? ' waking' : ''}`);
      // While waking from a doze, the nightcap is still drawn so it can fly off.
      const drawn = st.capOff && st.stage > 1 ? 'waking' : st.mood;
      el.innerHTML = svg(st.stage, st.stage > 1 ? drawn : (st.mood === 'sleepy' || st.mood === 'dozing' ? st.mood : 'content'));
      el.setAttribute('aria-label', `A duckling, ${STAGES[st.stage].toLowerCase()}, ${st.mood}`);
    }
    function react(cls) { el.classList.remove('hop', 'wiggle'); void el.getBoundingClientRect(); el.classList.add(cls); setTimeout(() => el.classList.remove(cls), 700); }
    draw();
    return {
      get stage() { return st.stage }, get mood() { return st.mood },
      set(next) { Object.assign(st, next); draw(); },
      hop() { react(st.stage < 2 ? 'wiggle' : 'hop'); },
      wiggle() { react('wiggle'); },
      /// Somebody came back: the eyes flutter open, a long stretch, a shake,
      /// and a dozing duck's nightcap flies off.
      wake(to = 'content') {
        const wasDozing = st.mood === 'dozing';
        el.classList.remove('waking');
        Object.assign(st, { mood: to, capOff: wasDozing });
        draw();
        void el.getBoundingClientRect();
        el.classList.add('waking');
        setTimeout(() => { st.capOff = false; draw(); el.classList.remove('waking'); }, 1700);
      },
    };
  }

  window.Duck = { STAGES, SCALE, MOODS, svg, mount };
})();
