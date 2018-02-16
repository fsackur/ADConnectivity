#Class architecture

#DomainMember
Has:
- Hostname
- IP
- State (Member/DC)
- Domain
- Site
- DNS servers
- DomainControllers
- FSMOs
    - PDC
- TimeSync

Does:
- Initialise (populates from WMI)
- Test (requires access by remoting / WMI / etc or throws exception. Expected to be run on localmachine)

It is expected that methods are only used on localhost:
$Localhost = DomainMember.new()
$Localhost.Initialise()
$Localhost.Test()


#DomainMembership
enum: workgroup / member / DC

#Domain
Has:
- Netbios
- DNS domain
- Parent
- Children

Factory - only one instance of given domain - constructor is private
both properties must be unique or throws NameNotUniqueException

#DomainFactory
has collection of Domains

#DNS Server
Has:
- IP
- Cache

Does:
- Query(RecordType, Data)
- QueryPDC(Domain)


#DomainController : DomainMember
Has:
- CurrentReplicationPartners
- PossibleReplicationPartners
- TimeSinceLastRepl