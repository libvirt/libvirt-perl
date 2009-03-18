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
    (void)hv_store (hv, "code", 4, newSViv (error ? error->code : 0), 0);
    (void)hv_store (hv, "domain", 6, newSViv (error ? error->domain : VIR_FROM_NONE), 0);
    (void)hv_store (hv, "message", 7, newSVpv (error ? error->message : "Unknown problem", 0), 0);

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
_populate_constant(HV *stash, char *name, int val)
{
    SV *valsv;

    valsv = newSViv(0);
    sv_setuv(valsv,val);
    newCONSTSUB(stash, name, valsv);
}

#define REGISTER_CONSTANT(name, key) _populate_constant(stash, #key, name)

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
_get_library_version(void)
 PREINIT:
      unsigned long version;
   CODE:
      if (virGetVersion(&version, NULL, NULL) < 0) {
	_croak_error(virGetLastError());
      }
      RETVAL = version;
  OUTPUT:
      RETVAL

unsigned long
_get_conn_version(con)
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

char *
get_uri(con)
      virConnectPtr con;
   CODE:
      RETVAL = virConnectGetURI(con);
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
      (void)hv_store (RETVAL, "model", 5, newSVpv(info.model, 0), 0);
      (void)hv_store (RETVAL, "memory", 6, newSViv(info.memory), 0);
      (void)hv_store (RETVAL, "cpus", 4, newSViv(info.cpus), 0);
      (void)hv_store (RETVAL, "mhz", 3, newSViv(info.mhz), 0);
      (void)hv_store (RETVAL, "nodes", 5, newSViv(info.nodes), 0);
      (void)hv_store (RETVAL, "sockets", 7, newSViv(info.sockets), 0);
      (void)hv_store (RETVAL, "cores", 5, newSViv(info.cores), 0);
      (void)hv_store (RETVAL, "threads", 7, newSViv(info.threads), 0);
  OUTPUT:
      RETVAL


HV *
get_node_security_model(con)
      virConnectPtr con;
 PREINIT:
      virSecurityModel secmodel;
    CODE:
      if (virNodeGetSecurityModel(con, &secmodel) < 0) {
	_croak_error(virConnGetLastError(con));
      }
      RETVAL = newHV();
      (void)hv_store (RETVAL, "model", 5, newSVpv(secmodel.model, 0), 0);
      (void)hv_store (RETVAL, "doi", 3, newSVpv(secmodel.doi, 0), 0);
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
      Safefree(ids);


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
      Safefree(names);


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
      Safefree(names);


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
      Safefree(names);


int
num_of_storage_pools(con)
      virConnectPtr con;
    CODE:
      if ((RETVAL = virConnectNumOfStoragePools(con)) < 0) {
	_croak_error(virConnGetLastError(con));
      }
  OUTPUT:
      RETVAL

void
list_storage_pool_names(con, maxnames)
      virConnectPtr con;
      int maxnames;
 PREINIT:
      char **names;
      int i, nnet;
  PPCODE:
      Newx(names, maxnames, char *);
      if ((nnet = virConnectListStoragePools(con, names, maxnames)) < 0) {
	_croak_error(virConnGetLastError(con));
      }
      EXTEND(SP, nnet);
      for (i = 0 ; i < nnet ; i++) {
	PUSHs(sv_2mortal(newSVpv(names[i], 0)));
	free(names[i]);
      }
      Safefree(names);


int
num_of_defined_storage_pools(con)
      virConnectPtr con;
    CODE:
      if ((RETVAL = virConnectNumOfDefinedStoragePools(con)) < 0) {
	_croak_error(virConnGetLastError(con));
      }
  OUTPUT:
      RETVAL

void
list_defined_storage_pool_names(con, maxnames)
      virConnectPtr con;
      int maxnames;
 PREINIT:
      char **names;
      int ndom;
      int i;
  PPCODE:
      Newx(names, maxnames, char *);
      if ((ndom = virConnectListDefinedStoragePools(con, names, maxnames)) < 0) {
	free(names);
	_croak_error(virConnGetLastError(con));
      }
      EXTEND(SP, ndom);
      for (i = 0 ; i < ndom ; i++) {
	PUSHs(sv_2mortal(newSVpv(names[i], 0)));
        free(names[i]);
      }
      Safefree(names);


int
num_of_node_devices(con, cap, flags)
      virConnectPtr con;
      const char *cap;
      int flags
    CODE:
      if ((RETVAL = virNodeNumOfDevices(con, cap, flags)) < 0) {
	_croak_error(virConnGetLastError(con));
      }
  OUTPUT:
      RETVAL

void
list_node_device_names(con, cap, maxnames, flags)
      virConnectPtr con;
      const char *cap;
      int maxnames;
      int flags;
 PREINIT:
      char **names;
      int i, nnet;
  PPCODE:
      Newx(names, maxnames, char *);
      if ((nnet = virNodeListDevices(con, cap, names, maxnames, flags)) < 0) {
	_croak_error(virConnGetLastError(con));
      }
      EXTEND(SP, nnet);
      for (i = 0 ; i < nnet ; i++) {
	PUSHs(sv_2mortal(newSVpv(names[i], 0)));
	free(names[i]);
      }
      Safefree(names);



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
      /* Don't bother using virDomainCreateXML, since this works
         for more versions */
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

void
core_dump(dom, to, flags)
      virDomainPtr dom;
      const char *to
      unsigned int flags;
    PPCODE:
      if (virDomainCoreDump(dom, to, flags) < 0) {
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
      (void)hv_store (RETVAL, "state", 5, newSViv(info.state), 0);
      (void)hv_store (RETVAL, "maxMem", 6, newSViv(info.maxMem), 0);
      (void)hv_store (RETVAL, "memory", 6, newSViv(info.memory), 0);
      (void)hv_store (RETVAL, "nrVirtCpu", 9, newSViv(info.nrVirtCpu), 0);
      (void)hv_store (RETVAL, "cpuTime", 7, newSViv(info.cpuTime), 0);
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


void
set_vcpus(dom, num)
      virDomainPtr dom;
      int num;
  PPCODE:
      if (virDomainSetVcpus(dom, num) < 0) {
	_croak_error(virConnGetLastError(virDomainGetConnect(dom)));
      }


void
set_autostart(dom, autostart)
      virDomainPtr dom;
      int autostart;
  PPCODE:
      if (virDomainSetAutostart(dom, autostart) < 0) {
	_croak_error(virConnGetLastError(virDomainGetConnect(dom)));
      }


int
get_autostart(dom)
      virDomainPtr dom;
 PREINIT:
      int autostart;
    CODE:
      if (virDomainGetAutostart(dom, &autostart) < 0) {
	_croak_error(virConnGetLastError(virDomainGetConnect(dom)));
      }
      RETVAL = autostart;
  OUTPUT:
      RETVAL


char *
get_scheduler_type(dom)
      virDomainPtr dom;
PREINIT:
      int nparams;
    CODE:
      if ((RETVAL = virDomainGetSchedulerType(dom, &nparams)) == NULL) {
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


virDomainPtr
migrate(dom, destcon, flags, dname, uri, bandwidth)
     virDomainPtr dom;
     virConnectPtr destcon;
     unsigned long flags;
     const char *dname;
     const char *uri;
     unsigned long bandwidth;
   PPCODE:
     if ((RETVAL = virDomainMigrate(dom, destcon, flags, dname, uri, bandwidth)) == NULL) {
       _croak_error(virConnGetLastError(virDomainGetConnect(dom)));
     }

void
attach_device(dom, xml)
      virDomainPtr dom;
      const char *xml;
    PPCODE:
      if (virDomainAttachDevice(dom, xml) < 0) {
	_croak_error(virConnGetLastError(virDomainGetConnect(dom)));
      }


void
detach_device(dom, xml)
      virDomainPtr dom;
      const char *xml;
    PPCODE:
      if (virDomainDetachDevice(dom, xml) < 0) {
	_croak_error(virConnGetLastError(virDomainGetConnect(dom)));
      }


HV *
block_stats(dom, path)
      virDomainPtr dom;
      const char *path;
  PREINIT:
      virDomainBlockStatsStruct stats;
    CODE:
      if (virDomainBlockStats(dom, path, &stats, sizeof(stats)) < 0) {
	_croak_error(virConnGetLastError(virDomainGetConnect(dom)));
      }
      RETVAL = newHV();
      (void)hv_store (RETVAL, "rd_req", 6, newSViv(stats.rd_req), 0);
      (void)hv_store (RETVAL, "rd_bytes", 8, newSViv(stats.rd_bytes), 0);
      (void)hv_store (RETVAL, "wr_req", 6, newSViv(stats.wr_req), 0);
      (void)hv_store (RETVAL, "wr_bytes", 8, newSViv(stats.wr_bytes), 0);
      (void)hv_store (RETVAL, "errs", 4, newSViv(stats.errs), 0);
  OUTPUT:
      RETVAL


HV *
interface_stats(dom, path)
      virDomainPtr dom;
      const char *path;
  PREINIT:
      virDomainInterfaceStatsStruct stats;
    CODE:
      if (virDomainInterfaceStats(dom, path, &stats, sizeof(stats)) < 0) {
	_croak_error(virConnGetLastError(virDomainGetConnect(dom)));
      }
      RETVAL = newHV();
      (void)hv_store (RETVAL, "rx_bytes", 8, newSViv(stats.rx_bytes), 0);
      (void)hv_store (RETVAL, "rx_packets", 10, newSViv(stats.rx_packets), 0);
      (void)hv_store (RETVAL, "rx_errs", 7, newSViv(stats.rx_errs), 0);
      (void)hv_store (RETVAL, "rx_drop", 7, newSViv(stats.rx_drop), 0);
      (void)hv_store (RETVAL, "tx_bytes", 8, newSViv(stats.tx_bytes), 0);
      (void)hv_store (RETVAL, "tx_packets", 10, newSViv(stats.tx_packets), 0);
      (void)hv_store (RETVAL, "tx_errs", 7, newSViv(stats.tx_errs), 0);
      (void)hv_store (RETVAL, "tx_drop", 7, newSViv(stats.tx_drop), 0);
  OUTPUT:
      RETVAL


SV *
block_peek(dom, path, offset, size, flags)
      virDomainPtr dom;
      const char *path;
      unsigned int offset;
      size_t size;
      unsigned int flags;
  PREINIT:
      char *buf;
    CODE:
      Newx(buf, size, char);
      if (virDomainBlockPeek(dom, path, offset, size, buf, flags) < 0) {
	_croak_error(virConnGetLastError(virDomainGetConnect(dom)));
      }
      RETVAL = newSVpvn(buf, size);
  OUTPUT:
      RETVAL



SV *
memory_peek(dom, offset, size, flags)
      virDomainPtr dom;
      unsigned int offset;
      size_t size;
      unsigned int flags;
  PREINIT:
      char *buf;
    CODE:
      Newx(buf, size, char);
      if (virDomainMemoryPeek(dom, offset, size, buf, flags) < 0) {
	_croak_error(virConnGetLastError(virDomainGetConnect(dom)));
      }
      RETVAL = newSVpvn(buf, size);
  OUTPUT:
      RETVAL



HV *
get_security_label(dom)
      virDomainPtr dom;
 PREINIT:
      virSecurityLabel seclabel;
    CODE:
      if (virDomainGetSecurityLabel(dom, &seclabel) < 0) {
	_croak_error(virConnGetLastError(virDomainGetConnect(dom)));
      }
      RETVAL = newHV();
      (void)hv_store (RETVAL, "label", 5, newSVpv(seclabel.label, 0), 0);
      (void)hv_store (RETVAL, "enforcing", 9, newSViv(seclabel.enforcing), 0);
   OUTPUT:
      RETVAL


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
set_autostart(net, autostart)
      virNetworkPtr net;
      int autostart;
  PPCODE:
      if (virNetworkSetAutostart(net, autostart) < 0) {
	_croak_error(virConnGetLastError(virNetworkGetConnect(net)));
      }


int
get_autostart(net)
      virNetworkPtr net;
 PREINIT:
      int autostart;
    CODE:
      if (virNetworkGetAutostart(net, &autostart) < 0) {
	_croak_error(virConnGetLastError(virNetworkGetConnect(net)));
      }
      RETVAL = autostart;
  OUTPUT:
      RETVAL

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



MODULE = Sys::Virt::StoragePool  PACKAGE = Sys::Virt::StoragePool

virStoragePoolPtr
_create_xml(con, xml)
      virConnectPtr con;
      const char *xml;
    CODE:
      if (!(RETVAL = virStoragePoolCreateXML(con, xml, 0))) {
	_croak_error(virConnGetLastError(con));
      }
  OUTPUT:
      RETVAL

virStoragePoolPtr
_define_xml(con, xml)
      virConnectPtr con;
      const char *xml;
    CODE:
      if (!(RETVAL = virStoragePoolDefineXML(con, xml, 0))) {
	_croak_error(virConnGetLastError(con));
      }
  OUTPUT:
      RETVAL

virStoragePoolPtr
_lookup_by_name(con, name)
      virConnectPtr con;
      const char *name;
    CODE:
      if (!(RETVAL = virStoragePoolLookupByName(con, name))) {
	_croak_error(virConnGetLastError(con));
      }
  OUTPUT:
      RETVAL

virStoragePoolPtr
_lookup_by_uuid(con, uuid)
      virConnectPtr con;
      const unsigned char *uuid;
    CODE:
      if (!(RETVAL = virStoragePoolLookupByUUID(con, uuid))) {
	_croak_error(virConnGetLastError(con));
      }
  OUTPUT:
      RETVAL

virStoragePoolPtr
_lookup_by_uuid_string(con, uuid)
      virConnectPtr con;
      const char *uuid;
    CODE:
      if (!(RETVAL = virStoragePoolLookupByUUIDString(con, uuid))) {
	_croak_error(virConnGetLastError(con));
      }
  OUTPUT:
      RETVAL


virStoragePoolPtr
_lookup_by_volume(vol)
      virStorageVolPtr vol;
    CODE:
      if (!(RETVAL = virStoragePoolLookupByVolume(vol))) {
	_croak_error(virConnGetLastError(virStorageVolGetConnect(vol)));
      }
  OUTPUT:
      RETVAL


SV *
get_uuid(pool)
      virStoragePoolPtr pool;
  PREINIT:
      unsigned char rawuuid[16];
    CODE:
      if ((virStoragePoolGetUUID(pool, rawuuid)) < 0) {
	_croak_error(virConnGetLastError(virStoragePoolGetConnect(pool)));
      }
      RETVAL = newSVpv((char*)rawuuid, 16);
  OUTPUT:
      RETVAL

SV *
get_uuid_string(pool)
      virStoragePoolPtr pool;
  PREINIT:
      char uuid[36];
    CODE:
      if ((virStoragePoolGetUUIDString(pool, uuid)) < 0) {
	_croak_error(virConnGetLastError(virStoragePoolGetConnect(pool)));
      }

      RETVAL = newSVpv(uuid, 0);
  OUTPUT:
      RETVAL

const char *
get_name(pool)
      virStoragePoolPtr pool;
    CODE:
      if (!(RETVAL = virStoragePoolGetName(pool))) {
	_croak_error(virConnGetLastError(virStoragePoolGetConnect(pool)));
      }
  OUTPUT:
      RETVAL


SV *
get_xml_description(pool)
      virStoragePoolPtr pool;
  PREINIT:
      char *xml;
    CODE:
      if (!(xml = virStoragePoolGetXMLDesc(pool, 0))) {
	 _croak_error(virConnGetLastError(virStoragePoolGetConnect(pool)));
      }
      RETVAL = newSVpv(xml, 0);
      free(xml);
  OUTPUT:
      RETVAL

void
undefine(pool)
      virStoragePoolPtr pool;
    PPCODE:
      if (virStoragePoolUndefine(pool) < 0) {
	_croak_error(virConnGetLastError(virStoragePoolGetConnect(pool)));
      }

void
create(pool)
      virStoragePoolPtr pool;
    PPCODE:
      if (virStoragePoolCreate(pool, 0) < 0) {
	_croak_error(virConnGetLastError(virStoragePoolGetConnect(pool)));
      }

void
refresh(pool, flags)
      virStoragePoolPtr pool;
      int flags;
    PPCODE:
      if (virStoragePoolRefresh(pool, flags) < 0) {
	_croak_error(virConnGetLastError(virStoragePoolGetConnect(pool)));
      }

void
build(pool, flags)
      virStoragePoolPtr pool;
      int flags;
    PPCODE:
      if (virStoragePoolBuild(pool, flags) < 0) {
	_croak_error(virConnGetLastError(virStoragePoolGetConnect(pool)));
      }

void
delete(pool, flags)
      virStoragePoolPtr pool;
      int flags;
    PPCODE:
      if (virStoragePoolDelete(pool, flags) < 0) {
	_croak_error(virConnGetLastError(virStoragePoolGetConnect(pool)));
      }

void
set_autostart(pool, autostart)
      virStoragePoolPtr pool;
      int autostart;
  PPCODE:
      if (virStoragePoolSetAutostart(pool, autostart) < 0) {
	_croak_error(virConnGetLastError(virStoragePoolGetConnect(pool)));
      }


int
get_autostart(pool)
      virStoragePoolPtr pool;
 PREINIT:
      int autostart;
    CODE:
      if (virStoragePoolGetAutostart(pool, &autostart) < 0) {
	_croak_error(virConnGetLastError(virStoragePoolGetConnect(pool)));
      }
      RETVAL = autostart;
  OUTPUT:
      RETVAL


HV *
get_info(pool)
      virStoragePoolPtr pool;
  PREINIT:
      virStoragePoolInfo info;
    CODE:
      if (virStoragePoolGetInfo(pool, &info) < 0) {
	_croak_error(virConnGetLastError(virStoragePoolGetConnect(pool)));
      }
      RETVAL = newHV();
      (void)hv_store (RETVAL, "state", 5, newSViv(info.state), 0);
      (void)hv_store (RETVAL, "capacity", 8, newSViv(info.capacity), 0);
      (void)hv_store (RETVAL, "allocation", 10, newSViv(info.allocation), 0);
      (void)hv_store (RETVAL, "available", 9, newSViv(info.available), 0);
  OUTPUT:
      RETVAL

void
destroy(pool_rv)
      SV *pool_rv;
 PREINIT:
      virStoragePoolPtr pool;
  PPCODE:
      pool = (virStoragePoolPtr)SvIV((SV*)SvRV(pool_rv));
      if (virStoragePoolDestroy(pool) < 0) {
	_croak_error(virConnGetLastError(virStoragePoolGetConnect(pool)));
      }
      sv_setref_pv(pool_rv, "Sys::Virt::StoragePool", NULL);

int
num_of_storage_volumes(pool)
      virStoragePoolPtr pool;
    CODE:
      if ((RETVAL = virStoragePoolNumOfVolumes(pool)) < 0) {
	_croak_error(virConnGetLastError(virStoragePoolGetConnect(pool)));
      }
  OUTPUT:
      RETVAL

void
list_storage_vol_names(pool, maxnames)
      virStoragePoolPtr pool;
      int maxnames;
 PREINIT:
      char **names;
      int i, nnet;
  PPCODE:
      Newx(names, maxnames, char *);
      if ((nnet = virStoragePoolListVolumes(pool, names, maxnames)) < 0) {
	_croak_error(virConnGetLastError(virStoragePoolGetConnect(pool)));
      }
      EXTEND(SP, nnet);
      for (i = 0 ; i < nnet ; i++) {
	PUSHs(sv_2mortal(newSVpv(names[i], 0)));
	free(names[i]);
      }
      Safefree(names);



void
DESTROY(pool_rv)
      SV *pool_rv;
 PREINIT:
      virStoragePoolPtr pool;
  PPCODE:
      pool = (virStoragePoolPtr)SvIV((SV*)SvRV(pool_rv));
      if (pool) {
	virStoragePoolFree(pool);
      }


MODULE = Sys::Virt::StorageVol  PACKAGE = Sys::Virt::StorageVol

virStorageVolPtr
_create_xml(pool, xml, flags)
      virStoragePoolPtr pool;
      const char *xml;
      int flags;
    CODE:
      if (!(RETVAL = virStorageVolCreateXML(pool, xml, flags))) {
	_croak_error(virConnGetLastError(virStoragePoolGetConnect(pool)));
      }
  OUTPUT:
      RETVAL

virStorageVolPtr
_lookup_by_name(pool, name)
      virStoragePoolPtr pool;
      const char *name;
    CODE:
      if (!(RETVAL = virStorageVolLookupByName(pool, name))) {
	_croak_error(virConnGetLastError(virStoragePoolGetConnect(pool)));
      }
  OUTPUT:
      RETVAL

virStorageVolPtr
_lookup_by_key(con, key)
      virConnectPtr con;
      const char *key;
    CODE:
      if (!(RETVAL = virStorageVolLookupByKey(con, key))) {
	_croak_error(virConnGetLastError(con));
      }
  OUTPUT:
      RETVAL

virStorageVolPtr
_lookup_by_path(con, path)
      virConnectPtr con;
      const char *path;
    CODE:
      if (!(RETVAL = virStorageVolLookupByPath(con, path))) {
	_croak_error(virConnGetLastError(con));
      }
  OUTPUT:
      RETVAL

const char *
get_name(vol)
      virStorageVolPtr vol;
    CODE:
      if (!(RETVAL = virStorageVolGetName(vol))) {
	_croak_error(virConnGetLastError(virStorageVolGetConnect(vol)));
      }
  OUTPUT:
      RETVAL


const char *
get_key(vol)
      virStorageVolPtr vol;
    CODE:
      if (!(RETVAL = virStorageVolGetKey(vol))) {
	_croak_error(virConnGetLastError(virStorageVolGetConnect(vol)));
      }
  OUTPUT:
      RETVAL


const char *
get_path(vol)
      virStorageVolPtr vol;
    CODE:
      if (!(RETVAL = virStorageVolGetPath(vol))) {
	_croak_error(virConnGetLastError(virStorageVolGetConnect(vol)));
      }
  OUTPUT:
      RETVAL


SV *
get_xml_description(vol)
      virStorageVolPtr vol;
  PREINIT:
      char *xml;
    CODE:
      if (!(xml = virStorageVolGetXMLDesc(vol, 0))) {
	 _croak_error(virConnGetLastError(virStorageVolGetConnect(vol)));
      }
      RETVAL = newSVpv(xml, 0);
      free(xml);
  OUTPUT:
      RETVAL

void
delete(vol, flags)
      virStorageVolPtr vol;
      int flags;
    PPCODE:
      if (virStorageVolDelete(vol, flags) < 0) {
	_croak_error(virConnGetLastError(virStorageVolGetConnect(vol)));
      }


HV *
get_info(vol)
      virStorageVolPtr vol;
  PREINIT:
      virStorageVolInfo info;
    CODE:
      if (virStorageVolGetInfo(vol, &info) < 0) {
	_croak_error(virConnGetLastError(virStorageVolGetConnect(vol)));
      }
      RETVAL = newHV();
      (void)hv_store (RETVAL, "type", 4, newSViv(info.type), 0);
      (void)hv_store (RETVAL, "capacity", 8, newSViv(info.capacity), 0);
      (void)hv_store (RETVAL, "allocation", 10, newSViv(info.allocation), 0);
  OUTPUT:
      RETVAL

void
DESTROY(vol_rv)
      SV *vol_rv;
 PREINIT:
      virStorageVolPtr vol;
  PPCODE:
      vol = (virStorageVolPtr)SvIV((SV*)SvRV(vol_rv));
      if (vol) {
	virStorageVolFree(vol);
      }


MODULE = Sys::Virt::NodeDevice  PACKAGE = Sys::Virt::NodeDevice


virNodeDevicePtr
_lookup_by_name(con, name)
      virConnectPtr con;
      const char *name;
    CODE:
      if (!(RETVAL = virNodeDeviceLookupByName(con, name))) {
	_croak_error(virConnGetLastError(con));
      }
  OUTPUT:
      RETVAL

const char *
get_name(dev)
      virNodeDevicePtr dev;
    CODE:
      if (!(RETVAL = virNodeDeviceGetName(dev))) {
	_croak_error(virGetLastError());
      }
  OUTPUT:
      RETVAL


const char *
get_parent(dev)
      virNodeDevicePtr dev;
    CODE:
      if (!(RETVAL = virNodeDeviceGetParent(dev))) {
	_croak_error(virGetLastError());
      }
  OUTPUT:
      RETVAL


SV *
get_xml_description(dev)
      virNodeDevicePtr dev;
  PREINIT:
      char *xml;
    CODE:
      if (!(xml = virNodeDeviceGetXMLDesc(dev, 0))) {
	_croak_error(virGetLastError());
      }
      RETVAL = newSVpv(xml, 0);
      free(xml);
  OUTPUT:
      RETVAL

void
dettach(dev)
      virNodeDevicePtr dev;
    PPCODE:
      if (virNodeDeviceDettach(dev) < 0) {
	_croak_error(virGetLastError());
      }

void
reattach(dev)
      virNodeDevicePtr dev;
    PPCODE:
      if (virNodeDeviceReAttach(dev) < 0) {
	_croak_error(virGetLastError());
      }

void
reset(dev)
      virNodeDevicePtr dev;
    PPCODE:
      if (virNodeDeviceReset(dev) < 0) {
	_croak_error(virGetLastError());
      }

void
list_capabilities(dev)
      virNodeDevicePtr dev;
 PREINIT:
      int maxnames;
      char **names;
      int i, nnet;
  PPCODE:
      if ((maxnames = virNodeDeviceNumOfCaps(dev)) < 0) {
	_croak_error(virGetLastError());
      }
      Newx(names, maxnames, char *);
      if ((nnet = virNodeDeviceListCaps(dev, names, maxnames)) < 0) {
	_croak_error(virGetLastError());
      }
      EXTEND(SP, nnet);
      for (i = 0 ; i < nnet ; i++) {
	PUSHs(sv_2mortal(newSVpv(names[i], 0)));
	free(names[i]);
      }
      Safefree(names);


void
DESTROY(dev_rv)
      SV *dev_rv;
 PREINIT:
      virNodeDevicePtr dev;
  PPCODE:
      dev = (virNodeDevicePtr)SvIV((SV*)SvRV(dev_rv));
      if (dev) {
	virNodeDeviceFree(dev);
      }



MODULE = Sys::Virt  PACKAGE = Sys::Virt


PROTOTYPES: ENABLE


BOOT:
    {
      HV *stash;

      virSetErrorFunc(NULL, ignoreVirErrorFunc);

      stash = gv_stashpv( "Sys::Virt", TRUE );

      /*
       * Not required
      REGISTER_CONSTANT(VIR_CONNECT_RO, CONNECT_RO);
      */

      REGISTER_CONSTANT(VIR_CRED_USERNAME, CRED_USERNAME);
      REGISTER_CONSTANT(VIR_CRED_AUTHNAME, CRED_AUTHNAME);
      REGISTER_CONSTANT(VIR_CRED_LANGUAGE, CRED_LANGUAGE);
      REGISTER_CONSTANT(VIR_CRED_CNONCE, CRED_CNONCE);
      REGISTER_CONSTANT(VIR_CRED_PASSPHRASE, CRED_PASSPHRASE);
      REGISTER_CONSTANT(VIR_CRED_ECHOPROMPT, CRED_ECHOPROMPT);
      REGISTER_CONSTANT(VIR_CRED_NOECHOPROMPT, CRED_NOECHOPROMPT);
      REGISTER_CONSTANT(VIR_CRED_REALM, CRED_REALM);
      REGISTER_CONSTANT(VIR_CRED_EXTERNAL, CRED_EXTERNAL);


      REGISTER_CONSTANT(VIR_EVENT_HANDLE_READABLE, EVENT_HANDLE_READABLE);
      REGISTER_CONSTANT(VIR_EVENT_HANDLE_WRITABLE, EVENT_HANDLE_WRITABLE);
      REGISTER_CONSTANT(VIR_EVENT_HANDLE_ERROR, EVENT_HANDLE_ERROR);
      REGISTER_CONSTANT(VIR_EVENT_HANDLE_HANGUP, EVENT_HANDLE_HANGUP);


      stash = gv_stashpv( "Sys::Virt::Domain", TRUE );
      REGISTER_CONSTANT(VIR_DOMAIN_NOSTATE, STATE_NOSTATE);
      REGISTER_CONSTANT(VIR_DOMAIN_RUNNING, STATE_RUNNING);
      REGISTER_CONSTANT(VIR_DOMAIN_BLOCKED, STATE_BLOCKED);
      REGISTER_CONSTANT(VIR_DOMAIN_PAUSED, STATE_PAUSED);
      REGISTER_CONSTANT(VIR_DOMAIN_SHUTDOWN, STATE_SHUTDOWN);
      REGISTER_CONSTANT(VIR_DOMAIN_SHUTOFF, STATE_SHUTOFF);
      REGISTER_CONSTANT(VIR_DOMAIN_CRASHED, STATE_CRASHED);

      /*
       * This constant is not really useful yet
      REGISTER_CONSTANT(VIR_DOMAIN_NONE, CREATE_NONE);
      */

      /* NB: skip VIR_DOMAIN_SCHED_FIELD_* constants, because
         those are not used from Perl code - handled internally
         in the XS layer */

      REGISTER_CONSTANT(VIR_MIGRATE_LIVE, MIGRATE_LIVE);


      REGISTER_CONSTANT(VIR_DOMAIN_XML_SECURE, XML_SECURE);
      REGISTER_CONSTANT(VIR_DOMAIN_XML_INACTIVE, XML_INACTIVE);

      REGISTER_CONSTANT(VIR_MEMORY_VIRTUAL, MEMORY_VIRTUAL);

      REGISTER_CONSTANT(VIR_VCPU_OFFLINE, VCPU_OFFLINE);
      REGISTER_CONSTANT(VIR_VCPU_RUNNING, VCPU_RUNNING);
      REGISTER_CONSTANT(VIR_VCPU_BLOCKED, VCPU_BLOCKED);


      REGISTER_CONSTANT(VIR_DOMAIN_EVENT_DEFINED, EVENT_DEFINED);
      REGISTER_CONSTANT(VIR_DOMAIN_EVENT_UNDEFINED, EVENT_UNDEFINED);
      REGISTER_CONSTANT(VIR_DOMAIN_EVENT_STARTED, EVENT_STARTED);
      REGISTER_CONSTANT(VIR_DOMAIN_EVENT_SUSPENDED, EVENT_SUSPENDED);
      REGISTER_CONSTANT(VIR_DOMAIN_EVENT_RESUMED, EVENT_RESUMED);
      REGISTER_CONSTANT(VIR_DOMAIN_EVENT_STOPPED, EVENT_STOPPED);

      REGISTER_CONSTANT(VIR_DOMAIN_EVENT_DEFINED_ADDED, EVENT_DEFINED_ADDED);
      REGISTER_CONSTANT(VIR_DOMAIN_EVENT_DEFINED_UPDATED, EVENT_DEFINED_UPDATED);

      REGISTER_CONSTANT(VIR_DOMAIN_EVENT_UNDEFINED_REMOVED, EVENT_UNDEFINED_REMOVED);

      REGISTER_CONSTANT(VIR_DOMAIN_EVENT_STARTED_BOOTED, EVENT_STARTED_BOOTED);
      REGISTER_CONSTANT(VIR_DOMAIN_EVENT_STARTED_MIGRATED, EVENT_STARTED_MIGRATED);
      REGISTER_CONSTANT(VIR_DOMAIN_EVENT_STARTED_RESTORED, EVENT_STARTED_RESTORED);

      REGISTER_CONSTANT(VIR_DOMAIN_EVENT_SUSPENDED_PAUSED, EVENT_SUSPENDED_PAUSED);
      REGISTER_CONSTANT(VIR_DOMAIN_EVENT_SUSPENDED_MIGRATED, EVENT_SUSPENDED_MIGRATED);

      REGISTER_CONSTANT(VIR_DOMAIN_EVENT_RESUMED_UNPAUSED, EVENT_RESUMED_UNPAUSED);
      REGISTER_CONSTANT(VIR_DOMAIN_EVENT_RESUMED_MIGRATED, EVENT_RESUMED_MIGRATED);

      REGISTER_CONSTANT(VIR_DOMAIN_EVENT_STOPPED_SHUTDOWN, EVENT_STOPPED_SHUTDOWN);
      REGISTER_CONSTANT(VIR_DOMAIN_EVENT_STOPPED_DESTROYED, EVENT_STOPPED_DESTROYED);
      REGISTER_CONSTANT(VIR_DOMAIN_EVENT_STOPPED_CRASHED, EVENT_STOPPED_CRASHED);
      REGISTER_CONSTANT(VIR_DOMAIN_EVENT_STOPPED_MIGRATED, EVENT_STOPPED_MIGRATED);
      REGISTER_CONSTANT(VIR_DOMAIN_EVENT_STOPPED_SAVED, EVENT_STOPPED_SAVED);
      REGISTER_CONSTANT(VIR_DOMAIN_EVENT_STOPPED_FAILED, EVENT_STOPPED_FAILED);



      stash = gv_stashpv( "Sys::Virt::StoragePool", TRUE );
      REGISTER_CONSTANT(VIR_STORAGE_POOL_INACTIVE, STATE_INACTIVE);
      REGISTER_CONSTANT(VIR_STORAGE_POOL_BUILDING, STATE_BUILDING);
      REGISTER_CONSTANT(VIR_STORAGE_POOL_RUNNING, STATE_RUNNING);
      REGISTER_CONSTANT(VIR_STORAGE_POOL_DEGRADED, STATE_DEGRADED);

      REGISTER_CONSTANT(VIR_STORAGE_POOL_BUILD_NEW, BUILD_NEW);
      REGISTER_CONSTANT(VIR_STORAGE_POOL_BUILD_REPAIR, BUILD_REPAIR);
      REGISTER_CONSTANT(VIR_STORAGE_POOL_BUILD_RESIZE, BUILD_RESIZE);

      REGISTER_CONSTANT(VIR_STORAGE_POOL_DELETE_NORMAL, DELETE_NORMAL);
      REGISTER_CONSTANT(VIR_STORAGE_POOL_DELETE_ZEROED, DELETE_ZEROED);


      stash = gv_stashpv( "Sys::Virt::StorageVol", TRUE );
      REGISTER_CONSTANT(VIR_STORAGE_VOL_FILE, TYPE_FILE);
      REGISTER_CONSTANT(VIR_STORAGE_VOL_BLOCK, TYPE_BLOCK);

      REGISTER_CONSTANT(VIR_STORAGE_VOL_DELETE_NORMAL, DELETE_NORMAL);
      REGISTER_CONSTANT(VIR_STORAGE_VOL_DELETE_ZEROED, DELETE_ZEROED);
    }
