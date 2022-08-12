const { buildWebStorage, setupCache } = window.AxiosCacheInterceptor;
const storage = buildWebStorage(sessionStorage, 'axios-cache:');
const axiosCached = setupCache(axios.create(), { storage });

changeVersion = function handleVersionedDocs(repository_nwo, basePath) {
    menuBackgroundImageClosed = "url(\"data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpolyline points='15 6 9 12 15 18'%3E%3C/polyline%3E%3C/svg%3E\")";
    menuBackgroundImageOpen = "url(\"data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpolyline points='6 9 12 15 18 9'%3E%3C/polyline%3E%3C/svg%3E\")";

    async function loadOptions(menu, dropdown) {
        const defaultBranchPromise = axiosCached.get(
            `https://api.github.com/repos/${repository_nwo}`,
        ).then(res => {
            return res.data.default_branch;
        });

        const statusPredicate = (status) => status === 404 || status >= 200 && status < 400
        const versionDir = await axiosCached.get(
            `https://api.github.com/repos/${repository_nwo}/git/trees/gh-pages`, {
                cache: {
                    cachePredicate: {
                        statusCheck: statusPredicate
                    }
                },
                validateStatus: statusPredicate
            }
        ).then(res => {
            if (res.status === 404) {
                return null;
            }

            return res.data.tree.find(t => {
                return t.path.toLowerCase() === 'version';
            });
        });

        if (versionDir === undefined || versionDir === null) {
            var options = [];
        } else {
            res = await axios.get(versionDir.url);
            var options = res.data.tree.map(t => {
                return {value: t.path, text: t.path};
            });
        };

        options = options.sort( (a, b) => b.value.localeCompare(a.value, undefined, { numeric:true }) );

        const defaultBranch = await defaultBranchPromise;
        options.unshift({ value: 'latest', text: defaultBranch });

        var current = "";
        const versionPath = `${basePath}/version/`;
        const path = window.location.pathname.toLowerCase();
        if (path.startsWith(versionPath)) {
            const start = versionPath.length;
            const end = path.indexOf('/', start);
            current = path.substring(start, end);
        } else {
            current = defaultBranch;
        }
        menu.innerHTML = `Plugin Version: ${current}`;
        menu.appendChild(dropdown);

        options.forEach( item => {
            var opt = document.createElement('a');
            opt.href = item.value === 'latest' ? '' : `${versionPath}/${item.value}`;
            opt.innerHTML = item.text;
            opt.style.cssText = `
            padding-left: 1rem;
            `

            if (item.value === options[0].value) {
                opt.className = "plugin-version-selected"
            }

            dropdown.appendChild(opt);
        });
    };

    function showMenu(menu, dropdown) {
        dropdown.style.display = 'block';
        menu.style.backgroundImage = menuBackgroundImageOpen;
    }

    function hideMenu(menu, dropdown) {
        dropdown.style.display = 'none';
        menu.style.backgroundImage = menuBackgroundImageClosed;
    }

    function toggleMenu(menu, dropdown) {
        if (dropdown.style.display == 'none') {
            showMenu(menu, dropdown);
        } else {
            hideMenu(menu, dropdown);
        }
    }

    function toggleMenuDisplay(menuElement, dropDownElement, e) {
        if (dropDownElement.contains(e.target)) {
            return;
        }

        if (menuElement.contains(e.target)) {
            toggleMenu(menuElement, dropDownElement);
        }
    }

    // get main menu element and style as needed
    menuElement = document.getElementById("plugin-version-menu");
    menuElement.style.backgroundImage = menuBackgroundImageOpen; // preload open image so no delay in rendering
    menuElement.className = 'plugin-version-menu-background-fonts-style';
    menuElement.style.cssText = `
      position: relative;
      width: 180px;
      border: 1px solit transparent;
      padding: 1rem 1rem;
      background-image: ${menuBackgroundImageClosed};
      background-repeat: no-repeat;
      background-position: 90% 40%;
    `;

    dropdown = document.createElement('div');
    dropdown.id = "plugin-version-dropdown";
    dropdown.className = 'plugin-version-menu-background-fonts-style';
    dropdown.style.cssText = `
      position: absolute;
      min-width: 145px;
      box-shadow: 0px 8px 16px 0px rgba(0,0,0,0.2);
      padding: 12px 16px;
      z-index: 1;
    `;
    // ensure initial style of drop down menu is set
    toggleMenu(menuElement, dropdown);

    // populate menu with available options and current version
    loadOptions(menuElement, dropdown);
    menuElement.addEventListener('click', function(e) {toggleMenuDisplay(menuElement, dropdown, e);})
    window.addEventListener('click', function(e){
        if (!menuElement.contains(e.target)){
            // Clicked outside the drop down menu
            hideMenu(menuElement, dropdown);
        }
    });
}(repository_nwo, basePath);
