function setTheme(theme) {
    if (theme === "dark") {
        jtd.setTheme('dark');
        document.documentElement.setAttribute('data-theme', 'dark');
        window.localStorage.setItem('theme', 'dark');
    } else {
        jtd.setTheme('light');
        document.documentElement.setAttribute('data-theme', 'light');
        window.localStorage.setItem('theme', 'light');
    }
}

if (window.matchMedia) {
    window.matchMedia('(prefers-color-scheme: dark)')
        .addEventListener('change', event => {
            if (event.matches) {
                setTheme('dark');
            } else {
                setTheme('light');
            }
        });
}

function getUserThemePreference() {
  return localStorage.getItem('theme') || getComputedStyle(document.documentElement).getPropertyValue('content') || 'system';
}

function saveUserThemePreference(preference) {
  localStorage.setItem('theme', preference);
}

function getAppliedMode(preference) {
  if (preference === 'dark') {
    return 'dark';
  }
  if (preference === 'light') {
    return 'light';
  }
  // system
  if (matchMedia('(prefers-color-scheme: dark)').matches) {
    return 'dark';
  }
  return 'light';
}

const colorScheme = document.querySelector('meta[name="color-scheme"]');
function setAppliedMode(mode) {
  setTheme(mode);
}

function modeSwitcher() {
    let currentMode = document.documentElement.getAttribute('data-theme');
    if (currentMode === "dark") {
        setAppliedMode('light');
        document.getElementById("theme-toggle").innerHTML = "Dark Mode";
      } else {
        setAppliedMode('dark');
        document.getElementById("theme-toggle").innerHTML = "Light Mode";
    }
}

let theme = getUserThemePreference();
setAppliedMode(getAppliedMode(theme));
