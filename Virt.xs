/* -*- c -*-
 *
 * Copyright (C) 2006 Red Hat
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
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
	_croak_error(virGetLastError());
      }

unsigned long
get_version(con)
      virConnectPtr con;
 PREINIT:
      unsigned long version;
   CODE:
      if (virConnectGetVersion(con, &version) < 0) {
	_croak_error(virGetLastError());
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
	_croak_error(virGetLastError());
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



AV *
_list_domain_ids(con)
      virConnectPtr con;
 PREINIT:
      int *ids;
      int nid;
      int i;
  CODE:
      if ((nid = virConnectNumOfDomains(con)) < 0) {
	_croak_error(virGetLastError());
      }
      Newx(ids, nid, int);
      if ((nid = virConnectListDomains(con, ids, nid)) < 0) {
	_croak_error(virGetLastError());
      }
      RETVAL = newAV();
      for (i = 0 ; i < nid ; i++) {
	SV *sv = newSViv(ids[i]);
	av_push(RETVAL, sv);
      }
      free(ids);
  OUTPUT:
      RETVAL

#define MAX_NAMES 255

#if 0
AV *
_list_defined_domains(con)
      virConnectPtr con;
 PREINIT:
      const char **names;
      int ndom;
      int i;
  CODE:
      Newx(names, MAX_NAMES, const char *);
      if ((ndom = virConnectListDefinedDomains(con, names, MAX_NAMES)) < 0) {
	free(names);
	_croak_error(virGetLastError());
      }
      RETVAL = newAV();
      for (i = 0 ; i < ndom ; i++) {
	SV *sv = newSVpv(names[i], 0);
	av_push(RETVAL, sv);
      }
      free(names);
  OUTPUT:
      RETVAL

#endif

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
	_croak_error(virGetLastError());
      }
  OUTPUT:
      RETVAL

virDomainPtr
_define_xml(con, xml)
      virConnectPtr con;
      const char *xml;
    CODE:
      if (!(RETVAL = virDomainDefineXML(con, xml))) {
	_croak_error(virGetLastError());
      }
  OUTPUT:
      RETVAL

virDomainPtr
_lookup_by_id(con, id)
      virConnectPtr con;
      int id;
    CODE:
      if (!(RETVAL = virDomainLookupByID(con, id))) {
	_croak_error(virGetLastError());
      }
  OUTPUT:
      RETVAL

virDomainPtr
_lookup_by_name(con, name)
      virConnectPtr con;
      const char *name;
    CODE:
      if (!(RETVAL = virDomainLookupByName(con, name))) {
	_croak_error(virGetLastError());
      }
  OUTPUT:
      RETVAL

virDomainPtr
_lookup_by_uuid(con, uuid)
      virConnectPtr con;
      const unsigned char *uuid;
    CODE:
      if (!(RETVAL = virDomainLookupByUUID(con, uuid))) {
	_croak_error(virGetLastError());
      }
  OUTPUT:
      RETVAL

virDomainPtr
_lookup_by_uuid_string(con, uuid)
      virConnectPtr con;
      const char *uuid;
    CODE:
      if (!(RETVAL = virDomainLookupByUUIDString(con, uuid))) {
	_croak_error(virGetLastError());
      }
  OUTPUT:
      RETVAL

int
get_id(dom)
      virDomainPtr dom;
    CODE:
      if ((RETVAL = virDomainGetID(dom)) < 0) {
	_croak_error(virGetLastError());
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
	_croak_error(virGetLastError());
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
	_croak_error(virGetLastError());
      }

      RETVAL = newSVpv(uuid, 0);
  OUTPUT:
      RETVAL

const char *
get_name(dom)
      virDomainPtr dom;
    CODE:
      if (!(RETVAL = virDomainGetName(dom))) {
	_croak_error(virGetLastError());
      }
  OUTPUT:
      RETVAL


void
suspend(dom)
      virDomainPtr dom;
  PPCODE:
      if ((virDomainSuspend(dom)) < 0) {
	_croak_error(virGetLastError());
      }


void
resume(dom)
      virDomainPtr dom;
  PPCODE:
      if ((virDomainResume(dom)) < 0) {
	_croak_error(virGetLastError());
      }


void
save(dom, to)
      virDomainPtr dom;
      const char *to
  PPCODE:
      if ((virDomainSave(dom, to)) < 0) {
	_croak_error(virGetLastError());
      }


HV *
get_info(dom)
      virDomainPtr dom;
  PREINIT:
      virDomainInfo info;
    CODE:
      if (virDomainGetInfo(dom, &info) < 0) {
	_croak_error(virGetLastError());
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
	_croak_error(virGetLastError());
      }
  OUTPUT:
      RETVAL

void
set_max_memory(dom, val)
      virDomainPtr dom;
      unsigned long val;
  PPCODE:
      if (virDomainSetMaxMemory(dom, val) < 0) {
	_croak_error(virGetLastError());
      }


void
set_memory(dom, val)
      virDomainPtr dom;
      unsigned long val;
  PPCODE:
      if (virDomainSetMemory(dom, val) < 0) {
	_croak_error(virGetLastError());
      }


SV *
get_os_type(dom)
      virDomainPtr dom;
  PREINIT:
      char *type;
    CODE:
      if (!(type = virDomainGetOSType(dom))) {
	 _croak_error(virGetLastError());
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
	 _croak_error(virGetLastError());
      }
      RETVAL = newSVpv(xml, 0);
      free(xml);
  OUTPUT:
      RETVAL

void
shutdown(dom)
      virDomainPtr dom;
    PPCODE:
      if (!virDomainShutdown(dom)) {
	_croak_error(virGetLastError());
      }

void
reboot(dom, flags)
      virDomainPtr dom;
      unsigned int flags;
    PPCODE:
      if (!virDomainReboot(dom, flags)) {
	_croak_error(virGetLastError());
      }

void
undefine(dom)
      virDomainPtr dom;
    PPCODE:
      if (!virDomainUndefine(dom)) {
	_croak_error(virGetLastError());
      }

void
create(dom)
      virDomainPtr dom;
    PPCODE:
      if (!virDomainCreate(dom)) {
	_croak_error(virGetLastError());
      }

void
destroy(dom_rv)
      SV *dom_rv;
 PREINIT:
      virDomainPtr dom;
  PPCODE:
      dom = (virDomainPtr)SvIV((SV*)SvRV(dom_rv));
      if (!virDomainDestroy(dom)) {
	_croak_error(virGetLastError());
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

      REGISTER_CONSTANT(VIR_DOMAIN_DESTROY, REBOOT_DESTROY);
      REGISTER_CONSTANT(VIR_DOMAIN_RESTART, REBOOT_RESTART);
      REGISTER_CONSTANT(VIR_DOMAIN_PRESERVE, REBOOT_PRESERVE);
      REGISTER_CONSTANT(VIR_DOMAIN_RENAME_RESTART, REBOOT_RENAME_RESTART);

    }
