# frozen_string_literal: true

# Ripped from http://libvirt.org/html/libvirt-virterror.html#virErrorNumber.
module VagrantPlugins
  module ProviderLibvirt
    module Util
      module ErrorCodes
        VIR_ERR_OK = 0
        VIR_ERR_INTERNAL_ERROR = 1 # internal error
        VIR_ERR_NO_MEMORY = 2 # memory allocation failure
        VIR_ERR_NO_SUPPORT = 3 # no support for this function
        VIR_ERR_UNKNOWN_HOST = 4 # could not resolve hostname
        VIR_ERR_NO_CONNECT = 5 # can't connect to hypervisor
        VIR_ERR_INVALID_CONN = 6 # invalid connection object
        VIR_ERR_INVALID_DOMAIN = 7 # invalid domain object
        VIR_ERR_INVALID_ARG = 8 # invalid function argument
        VIR_ERR_OPERATION_FAILED = 9 # a command to hypervisor failed
        VIR_ERR_GET_FAILED  = 10 # a HTTP GET command to failed
        VIR_ERR_POST_FAILED = 11 # a HTTP POST command to failed
        VIR_ERR_HTTP_ERROR  = 12 # unexpected HTTP error code
        VIR_ERR_SEXPR_SERIAL = 13 # failure to serialize an S-Expr
        VIR_ERR_NO_XEN = 14 # could not open Xen hypervisor control
        VIR_ERR_XEN_CALL = 15 # failure doing an hypervisor call
        VIR_ERR_OS_TYPE = 16 # unknown OS type
        VIR_ERR_NO_KERNEL = 17 # missing kernel information
        VIR_ERR_NO_ROOT = 18 # missing root device information
        VIR_ERR_NO_SOURCE = 19 # missing source device information
        VIR_ERR_NO_TARGET = 20 # missing target device information
        VIR_ERR_NO_NAME = 21 # missing domain name information
        VIR_ERR_NO_OS = 22 # missing domain OS information
        VIR_ERR_NO_DEVICE = 23 # missing domain devices information
        VIR_ERR_NO_XENSTORE = 24 # could not open Xen Store control
        VIR_ERR_DRIVER_FULL = 25 # too many drivers registered
        VIR_ERR_CALL_FAILED = 26 # not supported by the drivers (DEPRECATED)
        VIR_ERR_XML_ERROR = 27 # an XML description is not well formed or broken
        VIR_ERR_DOM_EXIST = 28 # the domain already exist
        VIR_ERR_OPERATION_DENIED = 29 # operation forbidden on read-only connections
        VIR_ERR_OPEN_FAILED = 30 # failed to open a conf file
        VIR_ERR_READ_FAILED = 31 # failed to read a conf file
        VIR_ERR_PARSE_FAILED = 32 # failed to parse a conf file
        VIR_ERR_CONF_SYNTAX = 33 # failed to parse the syntax of a conf file
        VIR_ERR_WRITE_FAILED = 34 # failed to write a conf file
        VIR_ERR_XML_DETAIL = 35 # detail of an XML error
        VIR_ERR_INVALID_NETWORK = 36 # invalid network object
        VIR_ERR_NETWORK_EXIST = 37 # the network already exist
        VIR_ERR_SYSTEM_ERROR  = 38 # general system call failure
        VIR_ERR_RPC = 39 # some sort of RPC error
        VIR_ERR_GNUTLS_ERROR = 40 # error from a GNUTLS call
        VIR_WAR_NO_NETWORK = 41 # failed to start network
        VIR_ERR_NO_DOMAIN = 42 # domain not found or unexpectedly disappeared
        VIR_ERR_NO_NETWORK  = 43 # network not found
        VIR_ERR_INVALID_MAC = 44 # invalid MAC address
        VIR_ERR_AUTH_FAILED = 45 # authentication failed
        VIR_ERR_INVALID_STORAGE_POOL = 46 # invalid storage pool object
        VIR_ERR_INVALID_STORAGE_VOL = 47 # invalid storage vol object
        VIR_WAR_NO_STORAGE = 48 # failed to start storage
        VIR_ERR_NO_STORAGE_POOL = 49 # storage pool not found
        VIR_ERR_NO_STORAGE_VOL  = 50 # storage volume not found
        VIR_WAR_NO_NODE = 51 # failed to start node driver
        VIR_ERR_INVALID_NODE_DEVICE = 52 # invalid node device object
        VIR_ERR_NO_NODE_DEVICE = 53 # node device not found
        VIR_ERR_NO_SECURITY_MODEL = 54 # security model not found
        VIR_ERR_OPERATION_INVALID = 55 # operation is not applicable at this time
        VIR_WAR_NO_INTERFACE  = 56 # failed to start interface driver
        VIR_ERR_NO_INTERFACE  = 57 # interface driver not running
        VIR_ERR_INVALID_INTERFACE = 58 # invalid interface object
        VIR_ERR_MULTIPLE_INTERFACES = 59 # more than one matching interface found
        VIR_WAR_NO_NWFILTER = 60 # failed to start nwfilter driver
        VIR_ERR_INVALID_NWFILTER = 61 # invalid nwfilter object
        VIR_ERR_NO_NWFILTER = 62 # nw filter pool not found
        VIR_ERR_BUILD_FIREWALL = 63 # nw filter pool not found
        VIR_WAR_NO_SECRET = 64 # failed to start secret storage
        VIR_ERR_INVALID_SECRET = 65 # invalid secret
        VIR_ERR_NO_SECRET = 66 # secret not found
        VIR_ERR_CONFIG_UNSUPPORTED = 67 # unsupported configuration construct
        VIR_ERR_OPERATION_TIMEOUT = 68 # timeout occurred during operation
        VIR_ERR_MIGRATE_PERSIST_FAILED = 69 # a migration worked, but making the VM persist on the dest host failed
        VIR_ERR_HOOK_SCRIPT_FAILED = 70 # a synchronous hook script failed
        VIR_ERR_INVALID_DOMAIN_SNAPSHOT = 71 # invalid domain snapshot
        VIR_ERR_NO_DOMAIN_SNAPSHOT = 72 # domain snapshot not found
        VIR_ERR_INVALID_STREAM = 73 # stream pointer not valid
        VIR_ERR_ARGUMENT_UNSUPPORTED  = 74 # valid API use but unsupported by the given driver
        VIR_ERR_STORAGE_PROBE_FAILED  = 75 # storage pool probe failed
        VIR_ERR_STORAGE_POOL_BUILT = 76 # storage pool already built
        VIR_ERR_SNAPSHOT_REVERT_RISKY = 77 # force was not requested for a risky domain snapshot revert
        VIR_ERR_OPERATION_ABORTED = 78 # operation on a domain was canceled/aborted by user
        VIR_ERR_AUTH_CANCELLED = 79 # authentication cancelled
        VIR_ERR_NO_DOMAIN_METADATA = 80 # The metadata is not present
        VIR_ERR_MIGRATE_UNSAFE = 81 # Migration is not safe
        VIR_ERR_OVERFLOW = 82 # integer overflow
        VIR_ERR_BLOCK_COPY_ACTIVE = 83 # action prevented by block copy job
        VIR_ERR_OPERATION_UNSUPPORTED = 84 # The requested operation is not supported
        VIR_ERR_SSH = 85 # error in ssh transport driver
        VIR_ERR_AGENT_UNRESPONSIVE = 86 # guest agent is unresponsive, not running or not usable
        VIR_ERR_RESOURCE_BUSY = 87 # resource is already in use
        VIR_ERR_ACCESS_DENIED = 88 # operation on the object/resource was denied
        VIR_ERR_DBUS_SERVICE  = 89 # error from a dbus service
        VIR_ERR_STORAGE_VOL_EXIST = 90 # the storage vol already exists
      end
    end
  end
end
