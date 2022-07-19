changeVersion = function handleVersionedDocs() {
    const basePath = '/vagrant-libvirt';

    async function loadOptions(select) {
        const defaultBranchPromise = axios.get(
            'https://api.github.com/repos/vagrant-libvirt/vagrant-libvirt',
        ).then(res => {
            return res.data.default_branch;
        });

        const versionDir = await axios.get(
            'https://api.github.com/repos/vagrant-libvirt/vagrant-libvirt/git/trees/gh-pages',
        ).then(res => {
            return res.data.tree.find(t => {
                return t.path.toLowerCase() === 'version';
            });

        }).catch(e => {
            if (e.response.status == "404") {
                return null;
            }

            throw(e);
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

    loadOptions(document.getElementById("docs-version"));

    return changeVersion;
}();
