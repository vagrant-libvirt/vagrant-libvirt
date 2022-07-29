
const basePath = '/vagrant-libvirt';
const repository_nwo = 'vagrant-libvirt/vagrant-libvirt';

const { buildWebStorage, setupCache } = window.AxiosCacheInterceptor;
const storage = buildWebStorage(sessionStorage, 'axios-cache:');
const axiosCached = setupCache(axios.create(), { storage });

changeVersion = function handleVersionedDocs(repository_nwo, basePath) {
    async function loadOptions(select) {
        const defaultBranchPromise = axiosCached.get(
            `https://api.github.com/repos/${repository_nwo}`,
        ).then(res => {
            return res.data.default_branch;
        });

        const statusPredicate = (status) => status === 404 || status > 200 && status < 400
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

        if (versionDir === null) {
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

        options.forEach( item => {
            var opt = document.createElement('option');
            opt.value = item.value;
            opt.innerHTML = item.text;

            select.appendChild(opt);
        });

        const path = window.location.pathname.toLowerCase();
        const versionPath = `${basePath}/version/`;
        if (path.startsWith(versionPath)) {
            const start = versionPath.length;
            const end = path.indexOf('/', start);
            select.value = path.substring(start, end);
        } else {
            select.value = 'latest';
        }
    };

    function changeVersion(selectElement) {
        const targetVersionPath =
            selectElement.value === 'latest' ? '' : `/version/${selectElement.value}`;

        const path = window.location.pathname.toLowerCase();

        const versionPath = `${basePath}/version/`;
        const startIdx = path.startsWith(`${basePath}/version/`) ? versionPath.length : basePath.length;
        const endIdx = path.indexOf('/', startIdx);
        const targetPath =
            basePath + targetVersionPath + window.location.pathname.substring(endIdx);
        window.location.pathname = targetPath;
    };

    loadOptions(document.getElementById("plugin-version"));

    return changeVersion;
}(repository_nwo, basePath);
