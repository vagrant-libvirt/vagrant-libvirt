SCRIPT_DIR="$( cd "$BATS_TEST_DIRNAME" &> /dev/null && pwd )"
export PATH=$(dirname ${SCRIPT_DIR})/bin:${PATH}

VAGRANT_CMD="vagrant"
VAGRANT_OPT="--provider=libvirt"

TEMPDIR=


setup_file() {
  # set VAGRANT_HOME to something else to reuse for tests to avoid clashes with
  # user installed plugins when running tests locally.
  if [ -z "${VAGRANT_HOME:-}" ]
  then
    TEMPDIR=$(mktemp -d 2>/dev/null)

    export VAGRANT_HOME=${TEMPDIR}/.vagrant.d
    echo "# Using ${VAGRANT_HOME} for VAGRANT_HOME" >&3
  fi
}

teardown_file() {
  if [ -n "${TEMPDIR:-}" ] && [ -d "${TEMPDIR:-}" ]
  then
    rm -rf ${TEMPDIR:-}
  fi
}

cleanup() {
    ${VAGRANT_CMD} destroy -f
    if [ $? == "0" ]; then
        return 0
    else
        return 1
    fi
}

@test "destroy simple vm" {
  export VAGRANT_LOG=debug
  export VAGRANT_CWD=tests/simple
  run ${VAGRANT_CMD} up ${VAGRANT_OPT}
  echo "${output}"
  echo "status = ${status}"
  [ "$status" -eq 0 ]
  cleanup
}

@test "simple vm provision via shell" {
  export VAGRANT_CWD=tests/simple_provision_shell
  cleanup
  run ${VAGRANT_CMD} up ${VAGRANT_OPT}
  echo "status = ${status}"
  echo "${output}"
  [ "$status" -eq 0 ]
  [ $(expr "$output" : ".*Hello.*") -ne 0  ]
  echo "${output}"
  cleanup
}

@test "bring up with custom default prefix" {
  export VAGRANT_CWD=tests/default_prefix
  cleanup
  run ${VAGRANT_CMD} up ${VAGRANT_OPT}
  [ "$status" -eq 0 ]
  echo "${output}"
  echo "status = ${status}"
  [ $(expr "$output" : ".*changed_default_prefixdefault.*") -ne 0  ]
  echo "${output}"
  cleanup
}

@test "bring up with second disk" {
  export VAGRANT_CWD=tests/second_disk
  cleanup
  run ${VAGRANT_CMD} up ${VAGRANT_OPT}
  echo "${output}"
  echo "status = ${status}"
  [ "$status" -eq 0 ]
  echo "${output}"
  [ $(expr "$output" : ".*second_disk_default-vdb.*") -ne 0  ]
  run ${VAGRANT_CMD} halt
  echo "${output}"
  echo "status = ${status}"
  [ "$status" -eq 0 ]
  run ${VAGRANT_CMD} up ${VAGRANT_OPT}
  echo "${output}"
  echo "status = ${status}"
  [ "$status" -eq 0 ]
  cleanup
}

@test "bring up with two disks" {
  export VAGRANT_CWD=tests/two_disks
  cleanup
  tools/create_box_with_two_disks.sh ${VAGRANT_HOME} ${VAGRANT_CMD}
  run ${VAGRANT_CMD} up ${VAGRANT_OPT}
  echo "${output}"
  echo "status = ${status}"
  [ "$status" -eq 0 ]
  echo "${output}"
  [ $(expr "$output" : ".*Image.*2G")  -ne 0  ]
  [ $(expr "$output" : ".*Image.*10G") -ne 0  ]
  cleanup
}

@test "bring up with adjusted memory settings" {
  export VAGRANT_CWD=tests/memory
  cleanup
  run ${VAGRANT_CMD} up ${VAGRANT_OPT}
  echo "${output}"
  echo "status = ${status}"
  [ "$status" -eq 0 ]
  echo "${output}"
  [ $(expr "$output" : ".*Memory.*1000M.*") -ne 0  ]
  cleanup
}

@test "bring up with adjusted cpu settings" {
  export VAGRANT_CWD=tests/cpus
  cleanup
  run ${VAGRANT_CMD} up ${VAGRANT_OPT}
  echo "${output}"
  echo "status = ${status}"
  [ "$status" -eq 0 ]
  echo "${output}"
  [ $(expr "$output" : ".*Cpus.*2.*") -ne 0  ]
  cleanup
}

@test "bring up and use qemu agent for connectivity" {
  export VAGRANT_CWD=tests/qemu_agent
  cleanup
  run ${VAGRANT_CMD} up ${VAGRANT_OPT}
  echo "${output}"
  echo "status = ${status}"
  [ "$status" -eq 0 ]
  echo "${output}"
  cleanup
}

@test "ip is reachable with private network" {
  export VAGRANT_CWD=tests/private_network
  cleanup
  run ${VAGRANT_CMD} up ${VAGRANT_OPT}
  echo "${output}"
  echo "status = ${status}"
  [ "$status" -eq 0 ]
  echo "${output}"
  [ $(expr "$output" : ".*Cpus.*2.*") -ne 0  ]
  run fping 10.20.30.40
  [ "$status" -eq 0 ]
  echo "${output}"
  [ $(expr "$output" : ".*alive.*") -ne 0  ]
  cleanup
}

@test "package simple domain" {
  export VAGRANT_CWD=tests/package_simple
  cleanup
  run ${VAGRANT_CMD} up ${VAGRANT_OPT}
  echo "${output}"
  echo "status = ${status}"
  [ "$status" -eq 0 ]
  rm -f package.box
  run ${VAGRANT_CMD} package
  echo "${output}"
  echo "status = ${status}"
  [ "$status" -eq 0 ]
  run ${VAGRANT_CMD} destroy -f
  echo "${output}"
  echo "status = ${status}"
  [ "$status" -eq 0 ]
  run ${VAGRANT_CMD} box add --force package.box --name test-package-simple-domain
  echo "${output}"
  echo "status = ${status}"
  [ "$status" -eq 0 ]
  VAGRANT_VAGRANTFILE=Vagrantfile.testbox run ${VAGRANT_CMD} up ${VAGRANT_OPT}
  echo "${output}"
  echo "status = ${status}"
  [ "$status" -eq 0 ]
  run ${VAGRANT_CMD} box remove --force test-package-simple-domain
  echo "${output}"
  echo "status = ${status}"
  [ "$status" -eq 0 ]
  rm -f package.box

  cleanup
}

@test "package complex example" {
  export VAGRANT_CWD=tests/package_complex_example
  # this will allow the host keys to be removed, and part of the sysprep script
  # adds a step to trigger the regeneration.
  export VAGRANT_LIBVIRT_VIRT_SYSPREP_OPERATIONS='defaults,-ssh-userdir,customize'
  export VAGRANT_LIBVIRT_VIRT_SYSPREP_OPTIONS="--run $(pwd)/tests/package_complex_example/scripts/sysprep.sh"
  cleanup
  run ${VAGRANT_CMD} up ${VAGRANT_OPT}
  echo "${output}"
  echo "status = ${status}"
  [ "$status" -eq 0 ]
  rm -f package.box
  run ${VAGRANT_CMD} package
  echo "${output}"
  echo "status = ${status}"
  [ "$status" -eq 0 ]
  run ${VAGRANT_CMD} destroy -f
  echo "${output}"
  echo "status = ${status}"
  [ "$status" -eq 0 ]
  run ${VAGRANT_CMD} box add --force package.box --name test-package-complex-example
  echo "${output}"
  echo "status = ${status}"
  [ "$status" -eq 0 ]
  VAGRANT_VAGRANTFILE=Vagrantfile.testbox run ${VAGRANT_CMD} up ${VAGRANT_OPT}
  echo "${output}"
  echo "status = ${status}"
  [ "$status" -eq 0 ]
  run ${VAGRANT_CMD} box remove --force test-package-complex-example
  echo "${output}"
  echo "status = ${status}"
  [ "$status" -eq 0 ]
  rm -f package.box

  cleanup
}

@test "bring up and save a snapshot and restore it" {
  export VAGRANT_CWD=tests/snapshot

  cleanup
  run ${VAGRANT_CMD} up ${VAGRANT_OPT}
  echo "${output}"
  echo "status = ${status}"
  [ "$status" -eq 0 ]
  run ${VAGRANT_CMD} ssh -- -t 'touch a.txt'
  echo "${output}"
  echo "status = ${status}"
  [ "$status" -eq 0 ]
  run ${VAGRANT_CMD} snapshot save default test
  echo "${output}"
  echo "status = ${status}"
  [ "$status" -eq 0 ]
  run ${VAGRANT_CMD} ssh -- -t 'rm a.txt'
  echo "${output}"
  echo "status = ${status}"
  [ "$status" -eq 0 ]
  run ${VAGRANT_CMD} ssh -- -t 'ls a.txt'
  echo "${output}"
  echo "status = ${status}"
  # This means that the file does not exist on the box.
  [ "$status" -eq 1 ]
  run ${VAGRANT_CMD} ssh -- -t 'touch b.txt'
  echo "${output}"
  echo "status = ${status}"
  [ "$status" -eq 0 ]
  run ${VAGRANT_CMD} snapshot restore default test
  echo "${output}"
  echo "status = ${status}"
  [ "$status" -eq 0 ]
  run ${VAGRANT_CMD} ssh -- -t 'ls b.txt'
  echo "${output}"
  echo "status = ${status}"
  # This means that the file does not exist on the box.
  [ "$status" -eq 1 ]
  run ${VAGRANT_CMD} ssh -- -t 'ls a.txt'
  echo "${output}"
  echo "status = ${status}"
  [ "$status" -eq 0 ]
  run ${VAGRANT_CMD} snapshot delete default test
  echo "${output}"
  echo "status = ${status}"
  [ "$status" -eq 0 ]

  cleanup
}
