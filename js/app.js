// 앱 시작점: 주소의 # 부분을 보고 화면을 바꿔 끼워요. (04-tech 3번)

import { APP_NAME } from './config.js';
import { renderHome } from './screens/home.js';
import { renderHistory } from './screens/history.js';
import { renderStats } from './screens/stats.js';
import { renderSettings } from './screens/settings.js';

const routes = {
  home: renderHome,
  history: renderHistory,
  stats: renderStats,
  settings: renderSettings,
};

const screenEl = document.getElementById('screen');
const tabLinks = document.querySelectorAll('#tabbar a');

function currentRoute() {
  const name = location.hash.replace(/^#\//, '');
  return routes[name] ? name : 'home';
}

function render() {
  const name = currentRoute();
  screenEl.innerHTML = '';
  routes[name](screenEl);
  tabLinks.forEach((a) => a.classList.toggle('active', a.dataset.tab === name));
  window.scrollTo(0, 0);
}

document.title = APP_NAME;
window.addEventListener('hashchange', render);
render();
