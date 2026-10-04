// 아직 만들지 않은 화면에 보여주는 "준비 중" 표시

import { APP_NAME } from '../config.js';

export function renderPlaceholder(el, { title, message, orca = 'sleep' }) {
  el.innerHTML = `
    <section class="placeholder">
      <img src="assets/orca/${orca}.png" alt="">
      <h1>${title}</h1>
      <p>${message}</p>
      <p>${APP_NAME}</p>
    </section>
  `;
}
