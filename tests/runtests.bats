VAGRANT_CMD=/tmp/exec/vagrant
#VAGRANT_CMD=vagrant
VAGRANT_OPT="--provider=libvirt"

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

@test "simple vm rovision via shell" {
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

@test "bring up with custom default_prefix" {
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
