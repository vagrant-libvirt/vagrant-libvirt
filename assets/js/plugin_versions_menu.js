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

        var currentVersion = "";
        const versionPath = `${basePath}/version/`;
        const path = window.location.pathname.toLowerCase();
        if (path.startsWith(versionPath)) {
            const start = versionPath.length;
            const end = path.indexOf('/', start+1);
            currentVersion = path.substring(start, end < 0 ? path.length : end);
            currentPage = path.substring(end < 0 ? path.length : end);
        } else {
            currentVersion = defaultBranch;
            currentPage = path.substring(basePath.length);
        }
        menu.innerHTML = `Plugin Version: ${currentVersion}`;
        menu.appendChild(dropdown);

        options.forEach( item => {
            var link = document.createElement('a');
            var wrapper = document.createElement('div');
            link.href = (item.value === 'latest' ? basePath : versionPath + item.value) + currentPage;
            link.innerHTML = item.text;
            link.className = 'plugin-version-menu-option';
            link.style.cssText = `
            width: 100%;
            padding: 0.5rem 2rem 0.5rem 1rem;
            display: block;
            `;
            wrapper.style.cssText = `
            width: 100%;
            height: 100%;
            display: block;
            backdrop-filter: brightness(0.85);
            `;

            wrapper.addEventListener('mouseover', function(e) { brightenMenuOption(e.target); });
            wrapper.addEventListener('mouseout', function(e) { restoreMenuOption(e.target); });

            if (item.text === currentVersion) {
                link.style.fontWeight = 'bold';
            }

            wrapper.appendChild(link);
            dropdown.appendChild(wrapper);
        });
    };

    function brightenMenuOption(option) {
        option.style.backdropFilter = 'brightness(1.1)';
        // possible alternatives
        //option.style.boxShadow = 'inset 0 0 0 10em rgba(255, 255, 255, 0.6)';
        //option.style.backgroundColor = 'rgba(255,255,255,0.5)';
    }

    function restoreMenuOption(option) {
        option.style.backdropFilter = 'brightness(0.9)';
        //option.style.boxShadow = 'none';
        //option.style.backgroundColor = 'transparent';
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
      cursor: pointer;
    `;

    dropdown = document.createElement('div');
    dropdown.id = "plugin-version-dropdown";
    dropdown.className = 'plugin-version-menu-background-fonts-style';
    dropdown.style.cssText = `
      position: relative;
      top: 0.25rem;
      left: -0.25rem;
      min-width: 150px;
      box-shadow: 0px 8px 16px 0px rgba(0,0,0,0.4);
      padding: 0;
      z-index: 1;
    `;

    function showMenu() {
        dropdown.style.display = 'block';
        menuElement.style.backgroundImage = menuBackgroundImageOpen;
    }

    function hideMenu() {
        dropdown.style.display = 'none';
        menuElement.style.backgroundImage = menuBackgroundImageClosed;
    }

    function toggleMenu() {
        if (dropdown.style.display == 'none') {
            showMenu();
        } else {
            hideMenu();
        }
    }

    function toggleMenuDisplay(e) {
        if (dropdown.contains(e.target)) {
            return;
        }

        if (menuElement.contains(e.target)) {
            toggleMenu();
        }
    }

    // ensure initial style of drop down menu is set
    toggleMenu();

    // populate menu with available options and current version
    loadOptions(menuElement, dropdown);
    menuElement.addEventListener('click', toggleMenuDisplay)
    window.addEventListener('click', function(e){
        if (!menuElement.contains(e.target)){
            // Clicked outside the drop down menu
            hideMenu();
        }
    });
}(repository_nwo, basePath);
