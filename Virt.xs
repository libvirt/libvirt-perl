/* -*- c -*-
 *
 * Copyright (C) 2006 Red Hat
 * Copyright (C) 2006-2007 Daniel P. Berrange
 *
 * This program is free software; You can redistribute it and/or modify
 * it under either:
 *
 * a) the GNU General Public License as published by the Free
 *   Software Foundation; either version 2, or (at your option) any
 *   later version,
 *
 * or
 *
 * b) the "Artistic License"
 *
 * The file "LICENSE" distributed along with this file provides full
 * details of the terms and conditions of the two licenses.
 */

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <libvirt/virterror.h>
#include <libvirt/libvirt.h>

void	ignoreVirErrorFunc(void * userData, virErrorPtr error) {
  /* Do nothing */
}

SV *
_sv_from_error (virErrorPtr error)
{
    HV *hv;

    hv = newHV ();

    /* Map virErrorPtr attributes to hash keys */
    hv_store (hv, "code", 4, newSViv (error ? error->code : 0), 0);
    hv_store (hv, "domain", 6, newSViv (error ? error->domain : VIR_FROM_NONE), 0);
    hv_store (hv, "message", 7, newSVpv (error ? error->message : "Unknown problem", 0), 0);

    return sv_bless (newRV_noinc ((SV*) hv), gv_stashpv ("Sys::Virt::Error", TRUE));
}


void
_croak_error (virErrorPtr error)
{
    sv_setsv (ERRSV, _sv_from_error (error));

    /* croak does not return, so we free this now to avoid leaking */
    virResetError (error);

    croak (Nullch);
}

void
_populate_constant(HV *href, char *name, int val)
{
    hv_store(href, name, strlen(name), newSViv(val), 0);
}

#define REGISTER_CONSTANT(name, key) _populate_constant(constants, #key, name)

MODULE = Sys::Virt  PACKAGE = Sys::Virt

PROTOTYPES: ENABLE

virConnectPtr
_open(name, readonly)
      char *name;
      int readonly;
    CODE:
      if (!strcmp(name, "")) {
	name = NULL;
      }
      if (readonly) {
	RETVAL = virConnectOpenReadOnly(name);
      } else {
	RETVAL = virConnectOpen(name);
      }
      if (!RETVAL) {
	_croak_error(virGetLastError());
      }
  OUTPUT:
      RETVAL

void
restore_domain(con, from)
      virConnectPtr con;
      const char *from;
  PPCODE:
      if((virDomainRestore(con, from)) < 0) {
	_croak_error(virConnGetLastError(con));
      }

unsigned long
get_version(con)
      virConnectPtr con;
 PREINIT:
      unsigned long version;
   CODE:
      if (virConnectGetVersion(con, &version) < 0) {
	_croak_error(virConnGetLastError(con));
      }
      RETVAL = version;
  OUTPUT:
      RETVAL

const char *
get_type(con)
      virConnectPtr con;
   CODE:
      RETVAL = virConnectGetType(con);
 OUTPUT:
      RETVAL

HV *
get_node_info(con)
      virConnectPtr con;
  PREINIT:
      virNodeInfo info;
    CODE:
      if (virNodeGetInfo(con, &info) < 0) {
	_croak_error(virConnGetLastError(con));
      }
      RETVAL = newHV();
      hv_store (RETVAL, "model", 5, newSVpv(info.model, 0), 0);
      hv_store (RETVAL, "memory", 6, newSViv(info.memory), 0);
      hv_store (RETVAL, "cpus", 4, newSViv(info.cpus), 0);
      hv_store (RETVAL, "mhz", 3, newSViv(info.mhz), 0);
      hv_store (RETVAL, "nodes", 5, newSViv(info.nodes), 0);
      hv_store (RETVAL, "sockets", 7, newSViv(info.sockets), 0);
      hv_store (RETVAL, "cores", 5, newSViv(info.cores), 0);
      hv_store (RETVAL, "threads", 7, newSViv(info.threads), 0);
  OUTPUT:
      RETVAL

SV *
get_capabilities(con)
      virConnectPtr con;
PREINIT:
      char *xml;
   CODE:
      if (!(xml = virConnectGetCapabilities(con))) {
	 _croak_error(virConnGetLastError(con));
      }
      RETVAL = newSVpv(xml, 0);
      free(xml);
  OUTPUT:
      RETVAL

int
get_max_vcpus(con, type)
      virConnectPtr con;
      char *type;
    CODE:
      if ((RETVAL = virConnectGetMaxVcpus(con, type)) < 0) {
	_croak_error(virConnGetLastError(con));
      }
  OUTPUT:
      RETVAL

SV *
get_hostname(con)
      virConnectPtr con;
 PREINIT:
      char *host;
    CODE:
      if ((host = virConnectGetHostname(con)) < 0) {
	_croak_error(virConnGetLastError(con));
      }
      RETVAL = newSVpv(host, 0);
      free(host);
  OUTPUT:
      RETVAL

int
num_of_domains(con)
      virConnectPtr con;
    CODE:
      if ((RETVAL = virConnectNumOfDomains(con)) < 0) {
	_croak_error(virConnGetLastError(con));
      }
  OUTPUT:
      RETVAL

void
list_domain_ids(con, maxids)
      virConnectPtr con;
      int maxids
 PREINIT:
      int *ids;
      int i, nid;
  PPCODE:
      Newx(ids, maxids, int);
      if ((nid = virConnectListDomains(con, ids, maxids)) < 0) {
	_croak_error(virConnGetLastError(con));
      }
      EXTEND(SP, nid);
      for (i = 0 ; i < nid ; i++) {
	PUSHs(sv_2mortal(newSViv(ids[i])));
      }
      free(ids);


int
num_of_defined_domains(con)
      virConnectPtr con;
    CODE:
      if ((RETVAL = virConnectNumOfDefinedDomains(con)) < 0) {
	_croak_error(virConnGetLastError(con));
      }
  OUTPUT:
      RETVAL

void
list_defined_domain_names(con, maxnames)
      virConnectPtr con;
      int maxnames;
 PREINIT:
      char **names;
      int ndom;
      int i;
  PPCODE:
      Newx(names, maxnames, char *);
      if ((ndom = virConnectListDefinedDomains(con, names, maxnames)) < 0) {
	free(names);
	_croak_error(virConnGetLastError(con));
      }
      EXTEND(SP, ndom);
      for (i = 0 ; i < ndom ; i++) {
	PUSHs(sv_2mortal(newSVpv(names[i], 0)));
        free(names[i]);
      }
      free(names);


int
num_of_networks(con)
      virConnectPtr con;
    CODE:
      if ((RETVAL = virConnectNumOfNetworks(con)) < 0) {
	_croak_error(virConnGetLastError(con));
      }
  OUTPUT:
      RETVAL

void
list_network_names(con, maxnames)
      virConnectPtr con;
      int maxnames;
 PREINIT:
      char **names;
      int i, nnet;
  PPCODE:
      Newx(names, maxnames, char *);
      if ((nnet = virConnectListNetworks(con, names, maxnames)) < 0) {
	_croak_error(virConnGetLastError(con));
      }
      EXTEND(SP, nnet);
      for (i = 0 ; i < nnet ; i++) {
	PUSHs(sv_2mortal(newSVpv(names[i], 0)));
	free(names[i]);
      }
      free(names);


int
num_of_defined_networks(con)
      virConnectPtr con;
    CODE:
      if ((RETVAL = virConnectNumOfDefinedNetworks(con)) < 0) {
	_croak_error(virConnGetLastError(con));
      }
  OUTPUT:
      RETVAL

void
list_defined_network_names(con, maxnames)
      virConnectPtr con;
      int maxnames;
 PREINIT:
      char **names;
      int ndom;
      int i;
  PPCODE:
      Newx(names, maxnames, char *);
      if ((ndom = virConnectListDefinedNetworks(con, names, maxnames)) < 0) {
	free(names);
	_croak_error(virConnGetLastError(con));
      }
      EXTEND(SP, ndom);
      for (i = 0 ; i < ndom ; i++) {
	PUSHs(sv_2mortal(newSVpv(names[i], 0)));
        free(names[i]);
      }
      free(names);


void
DESTROY(con)
      virConnectPtr con;
  PPCODE:
      virConnectClose(con);

MODULE = Sys::Virt::Domain  PACKAGE = Sys::Virt::Domain

virDomainPtr
_create_linux(con, xml)
      virConnectPtr con;
      const char *xml;
    CODE:
      if (!(RETVAL = virDomainCreateLinux(con, xml, 0))) {
	_croak_error(virConnGetLastError(con));
      }
  OUTPUT:
      RETVAL

virDomainPtr
_define_xml(con, xml)
      virConnectPtr con;
      const char *xml;
    CODE:
      if (!(RETVAL = virDomainDefineXML(con, xml))) {
	_croak_error(virConnGetLastError(con));
      }
  OUTPUT:
      RETVAL

virDomainPtr
_lookup_by_id(con, id)
      virConnectPtr con;
      int id;
    CODE:
      if (!(RETVAL = virDomainLookupByID(con, id))) {
	_croak_error(virConnGetLastError(con));
      }
  OUTPUT:
      RETVAL

virDomainPtr
_lookup_by_name(con, name)
      virConnectPtr con;
      const char *name;
    CODE:
      if (!(RETVAL = virDomainLookupByName(con, name))) {
	_croak_error(virConnGetLastError(con));
      }
  OUTPUT:
      RETVAL

virDomainPtr
_lookup_by_uuid(con, uuid)
      virConnectPtr con;
      const unsigned char *uuid;
    CODE:
      if (!(RETVAL = virDomainLookupByUUID(con, uuid))) {
	_croak_error(virConnGetLastError(con));
      }
  OUTPUT:
      RETVAL

virDomainPtr
_lookup_by_uuid_string(con, uuid)
      virConnectPtr con;
      const char *uuid;
    CODE:
      if (!(RETVAL = virDomainLookupByUUIDString(con, uuid))) {
	_croak_error(virConnGetLastError(con));
      }
  OUTPUT:
      RETVAL

int
get_id(dom)
      virDomainPtr dom;
    CODE:
      if ((RETVAL = virDomainGetID(dom)) < 0) {
	_croak_error(virConnGetLastError(virDomainGetConnect(dom)));
      }
  OUTPUT:
      RETVAL


SV *
get_uuid(dom)
      virDomainPtr dom;
  PREINIT:
      unsigned char rawuuid[16];
    CODE:
      if ((virDomainGetUUID(dom, rawuuid)) < 0) {
	_croak_error(virConnGetLastError(virDomainGetConnect(dom)));
      }
      RETVAL = newSVpv((char*)rawuuid, 16);
  OUTPUT:
      RETVAL

SV *
get_uuid_string(dom)
      virDomainPtr dom;
  PREINIT:
      char uuid[36];
    CODE:
      if ((virDomainGetUUIDString(dom, uuid)) < 0) {
	_croak_error(virConnGetLastError(virDomainGetConnect(dom)));
      }

      RETVAL = newSVpv(uuid, 0);
  OUTPUT:
      RETVAL

const char *
get_name(dom)
      virDomainPtr dom;
    CODE:
      if (!(RETVAL = virDomainGetName(dom))) {
	_croak_error(virConnGetLastError(virDomainGetConnect(dom)));
      }
  OUTPUT:
      RETVAL


void
suspend(dom)
      virDomainPtr dom;
  PPCODE:
      if ((virDomainSuspend(dom)) < 0) {
	_croak_error(virConnGetLastError(virDomainGetConnect(dom)));
      }


void
resume(dom)
      virDomainPtr dom;
  PPCODE:
      if ((virDomainResume(dom)) < 0) {
	_croak_error(virConnGetLastError(virDomainGetConnect(dom)));
      }


void
save(dom, to)
      virDomainPtr dom;
      const char *to
  PPCODE:
      if ((virDomainSave(dom, to)) < 0) {
	_croak_error(virConnGetLastError(virDomainGetConnect(dom)));
      }


HV *
get_info(dom)
      virDomainPtr dom;
  PREINIT:
      virDomainInfo info;
    CODE:
      if (virDomainGetInfo(dom, &info) < 0) {
	_croak_error(virConnGetLastError(virDomainGetConnect(dom)));
      }
      RETVAL = newHV();
      hv_store (RETVAL, "state", 5, newSViv(info.state), 0);
      hv_store (RETVAL, "maxMem", 6, newSViv(info.maxMem), 0);
      hv_store (RETVAL, "memory", 6, newSViv(info.memory), 0);
      hv_store (RETVAL, "nrVirtCpu", 9, newSViv(info.nrVirtCpu), 0);
      hv_store (RETVAL, "cpuTime", 7, newSViv(info.cpuTime), 0);
  OUTPUT:
      RETVAL


unsigned long
get_max_memory(dom)
      virDomainPtr dom;
    CODE:
      if (!(RETVAL = virDomainGetMaxMemory(dom))) {
	_croak_error(virConnGetLastError(virDomainGetConnect(dom)));
      }
  OUTPUT:
      RETVAL

void
set_max_memory(dom, val)
      virDomainPtr dom;
      unsigned long val;
  PPCODE:
      if (virDomainSetMaxMemory(dom, val) < 0) {
	_croak_error(virConnGetLastError(virDomainGetConnect(dom)));
      }


void
set_memory(dom, val)
      virDomainPtr dom;
      unsigned long val;
  PPCODE:
      if (virDomainSetMemory(dom, val) < 0) {
	_croak_error(virConnGetLastError(virDomainGetConnect(dom)));
      }

int
get_max_vcpus(dom)
      virDomainPtr dom;
    CODE:
      if (!(RETVAL = virDomainGetMaxVcpus(dom))) {
	_croak_error(virConnGetLastError(virDomainGetConnect(dom)));
      }
  OUTPUT:
      RETVAL


SV *
get_os_type(dom)
      virDomainPtr dom;
  PREINIT:
      char *type;
    CODE:
      if (!(type = virDomainGetOSType(dom))) {
	 _croak_error(virConnGetLastError(virDomainGetConnect(dom)));
      }
      RETVAL = newSVpv(type, 0);
      free(type);
  OUTPUT:
      RETVAL

SV *
get_xml_description(dom)
      virDomainPtr dom;
  PREINIT:
      char *xml;
    CODE:
      if (!(xml = virDomainGetXMLDesc(dom, 0))) {
	 _croak_error(virConnGetLastError(virDomainGetConnect(dom)));
      }
      RETVAL = newSVpv(xml, 0);
      free(xml);
  OUTPUT:
      RETVAL

void
shutdown(dom)
      virDomainPtr dom;
    PPCODE:
      if (virDomainShutdown(dom) < 0) {
	_croak_error(virConnGetLastError(virDomainGetConnect(dom)));
      }

void
reboot(dom, flags)
      virDomainPtr dom;
      unsigned int flags;
    PPCODE:
      if (virDomainReboot(dom, flags) < 0) {
	_croak_error(virConnGetLastError(virDomainGetConnect(dom)));
      }

void
undefine(dom)
      virDomainPtr dom;
    PPCODE:
      if (virDomainUndefine(dom) < 0) {
	_croak_error(virConnGetLastError(virDomainGetConnect(dom)));
      }

void
create(dom)
      virDomainPtr dom;
    PPCODE:
      if (virDomainCreate(dom) < 0) {
	_croak_error(virConnGetLastError(virDomainGetConnect(dom)));
      }

void
destroy(dom_rv)
      SV *dom_rv;
 PREINIT:
      virDomainPtr dom;
  PPCODE:
      dom = (virDomainPtr)SvIV((SV*)SvRV(dom_rv));
      if (virDomainDestroy(dom) < 0) {
	_croak_error(virConnGetLastError(virDomainGetConnect(dom)));
      }
      sv_setref_pv(dom_rv, "Sys::Virt::Domain", NULL);

void
DESTROY(dom_rv)
      SV *dom_rv;
 PREINIT:
      virDomainPtr dom;
  PPCODE:
      dom = (virDomainPtr)SvIV((SV*)SvRV(dom_rv));
      if (dom) {
	virDomainFree(dom);
      }



MODULE = Sys::Virt::Network  PACKAGE = Sys::Virt::Network

virNetworkPtr
_create_xml(con, xml)
      virConnectPtr con;
      const char *xml;
    CODE:
      if (!(RETVAL = virNetworkCreateXML(con, xml))) {
	_croak_error(virConnGetLastError(con));
      }
  OUTPUT:
      RETVAL

virNetworkPtr
_define_xml(con, xml)
      virConnectPtr con;
      const char *xml;
    CODE:
      if (!(RETVAL = virNetworkDefineXML(con, xml))) {
	_croak_error(virConnGetLastError(con));
      }
  OUTPUT:
      RETVAL

virNetworkPtr
_lookup_by_name(con, name)
      virConnectPtr con;
      const char *name;
    CODE:
      if (!(RETVAL = virNetworkLookupByName(con, name))) {
	_croak_error(virConnGetLastError(con));
      }
  OUTPUT:
      RETVAL

virNetworkPtr
_lookup_by_uuid(con, uuid)
      virConnectPtr con;
      const unsigned char *uuid;
    CODE:
      if (!(RETVAL = virNetworkLookupByUUID(con, uuid))) {
	_croak_error(virConnGetLastError(con));
      }
  OUTPUT:
      RETVAL

virNetworkPtr
_lookup_by_uuid_string(con, uuid)
      virConnectPtr con;
      const char *uuid;
    CODE:
      if (!(RETVAL = virNetworkLookupByUUIDString(con, uuid))) {
	_croak_error(virConnGetLastError(con));
      }
  OUTPUT:
      RETVAL

SV *
get_uuid(net)
      virNetworkPtr net;
  PREINIT:
      unsigned char rawuuid[16];
    CODE:
      if ((virNetworkGetUUID(net, rawuuid)) < 0) {
	_croak_error(virConnGetLastError(virNetworkGetConnect(net)));
      }
      RETVAL = newSVpv((char*)rawuuid, 16);
  OUTPUT:
      RETVAL

SV *
get_uuid_string(net)
      virNetworkPtr net;
  PREINIT:
      char uuid[36];
    CODE:
      if ((virNetworkGetUUIDString(net, uuid)) < 0) {
	_croak_error(virConnGetLastError(virNetworkGetConnect(net)));
      }

      RETVAL = newSVpv(uuid, 0);
  OUTPUT:
      RETVAL

const char *
get_name(net)
      virNetworkPtr net;
    CODE:
      if (!(RETVAL = virNetworkGetName(net))) {
	_croak_error(virConnGetLastError(virNetworkGetConnect(net)));
      }
  OUTPUT:
      RETVAL


SV *
get_bridge_name(net)
      virNetworkPtr net;
  PREINIT:
      char *name;
    CODE:
      if (!(name = virNetworkGetBridgeName(net))) {
	 _croak_error(virConnGetLastError(virNetworkGetConnect(net)));
      }
      RETVAL = newSVpv(name, 0);
      free(name);
  OUTPUT:
      RETVAL

SV *
get_xml_description(net)
      virNetworkPtr net;
  PREINIT:
      char *xml;
    CODE:
      if (!(xml = virNetworkGetXMLDesc(net, 0))) {
	 _croak_error(virConnGetLastError(virNetworkGetConnect(net)));
      }
      RETVAL = newSVpv(xml, 0);
      free(xml);
  OUTPUT:
      RETVAL

void
undefine(net)
      virNetworkPtr net;
    PPCODE:
      if (virNetworkUndefine(net) < 0) {
	_croak_error(virConnGetLastError(virNetworkGetConnect(net)));
      }

void
create(net)
      virNetworkPtr net;
    PPCODE:
      if (virNetworkCreate(net) < 0) {
	_croak_error(virConnGetLastError(virNetworkGetConnect(net)));
      }

void
destroy(net_rv)
      SV *net_rv;
 PREINIT:
      virNetworkPtr net;
  PPCODE:
      net = (virNetworkPtr)SvIV((SV*)SvRV(net_rv));
      if (virNetworkDestroy(net) < 0) {
	_croak_error(virConnGetLastError(virNetworkGetConnect(net)));
      }
      sv_setref_pv(net_rv, "Sys::Virt::Network", NULL);

void
DESTROY(net_rv)
      SV *net_rv;
 PREINIT:
      virNetworkPtr net;
  PPCODE:
      net = (virNetworkPtr)SvIV((SV*)SvRV(net_rv));
      if (net) {
	virNetworkFree(net);
      }



MODULE = Sys::Virt  PACKAGE = Sys::Virt


PROTOTYPES: ENABLE

#define REGISTER_CONSTANT(name, key) _populate_constant(constants, #key, name)

BOOT:
    {
      HV *constants;

      virSetErrorFunc(NULL, ignoreVirErrorFunc);

      /* not the 'standard' way of doing perl constants, but a lot easier to maintain */

      constants = perl_get_hv("Sys::Virt::Domain::_constants", TRUE);
      REGISTER_CONSTANT(VIR_DOMAIN_NOSTATE, STATE_NOSTATE);
      REGISTER_CONSTANT(VIR_DOMAIN_RUNNING, STATE_RUNNING);
      REGISTER_CONSTANT(VIR_DOMAIN_BLOCKED, STATE_BLOCKED);
      REGISTER_CONSTANT(VIR_DOMAIN_PAUSED, STATE_PAUSED);
      REGISTER_CONSTANT(VIR_DOMAIN_SHUTDOWN, STATE_SHUTDOWN);
      REGISTER_CONSTANT(VIR_DOMAIN_SHUTOFF, STATE_SHUTOFF);
      REGISTER_CONSTANT(VIR_DOMAIN_CRASHED, STATE_CRASHED);
    }
