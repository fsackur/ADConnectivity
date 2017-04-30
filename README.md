# Test-ADDSConnectivity

Work in progress

.SYNOPSIS
    Runs a sequence of tests to determine whether connectivity supports correct AD operation

    Supports Server 2008 RTM onwards, Powershell 2 onwards

    Requires portqry.exe and nltest.exe

   
.DESCRIPTION
    Full description: runs a sequence of tests on member servers or domain controllers to identify AD connectivity issues

     - Member server:
        - Enumerate DNS servers
            - Test each of them returns A records for machine's domain
            - Test each of them returns SRV records for PDC
            - Test returned records match from all DNS servers
        - Test machine is in an AD Site
        - Test secure channel
        - Test all known AD ports, and RPC ports for AD RPC apps, to all domain controllers in site
        - Test NTP to PDC

     - Domain Controller:
        - All of the above, plus:
        - Checks recent replication status
        - Identifies all potential replication partners, not just current ones
        - Tests RPC port for AD replication service to all potential partners

     - This does not:
        - Port scan
            - DNS servers are polled for AD-related records which AD clients look up regularly
            - DC Locator services are polled in the same way that AD clients poll
            - Only known ports to DCs are tested. Traffic should be expected to these ports, as part of domain operation
            - AD-related RPC ports are identifed from the RPC EPM and targeted.
        - Make changes
