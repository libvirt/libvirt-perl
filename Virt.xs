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

/*
 * On 32-bit OS (and some 64-bit) Perl does not have an
 * integer type capable of storing 64 bit numbers. So
 * we serialize to/from strings on these platforms
 */

long long
virt_SvIVll(SV *sv) {
#ifdef USE_64_BIT_ALL
    return SvIV(sv);
#else
    return strtoll(SvPV_nolen(sv), NULL, 10);
#endif
}

unsigned long long
virt_SvIVull(SV *sv) {
#ifdef USE_64_BIT_ALL
    return SvIV(sv);
#else
    return strtoull(SvPV_nolen(sv), NULL, 10);
#endif
}


#ifndef PRId64
#define PRId64 "lld"
#endif

SV *
virt_newSVll(long long val) {
#ifdef USE_64_BIT_ALL
    return newSViv(val);
#else
    char buf[100];
    int len;
    len = snprintf(buf, 100, "%" PRId64, val);
    return newSVpv(buf, len);
#endif
}

#ifndef PRIu64
#define PRIu64 "llu"
#endif

SV *
virt_newSVull(unsigned long long val) {
#ifdef USE_64_BIT_ALL
    return newSVuv(val);
#else
    char buf[100];
    int len;
    len = snprintf(buf, 100, "%" PRIu64, val);
    return newSVpv(buf, len);
#endif
}



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

static int
_domain_event_callback(virConnectPtr con,
		       virDomainPtr dom,
		       int event,
		       int detail,
		       void *opaque)
{
    AV *data = opaque;
    SV **self;
    SV **cb;
    SV *domref;
    dSP;

    self = av_fetch(data, 0, 0);
    cb = av_fetch(data, 1, 0);

    SvREFCNT_inc(*self);

    ENTER;
    SAVETMPS;

    PUSHMARK(SP);
    XPUSHs(*self);
    domref = sv_newmortal();
    sv_setref_pv(domref, "Sys::Virt::Domain", (void*)dom);
    virDomainRef(dom);
    XPUSHs(domref);
    XPUSHs(sv_2mortal(newSViv(event)));
    XPUSHs(sv_2mortal(newSViv(detail)));
    PUTBACK;

    call_sv(*cb, G_DISCARD);

    FREETMPS;
    LEAVE;

    return 0;
}

static void
_domain_event_free(void *opaque)
{
  SV *sv = opaque;
  SvREFCNT_dec(sv);
}

static int
_event_add_handle(int fd,
		  int events,
		  virEventHandleCallback cb,
		  void *opaque,
		  virFreeCallback ff)
{
    SV *cbref;
    SV *opaqueref;
    SV *ffref;
    int ret;
    int watch = 0;
    dSP;

    ENTER;
    SAVETMPS;

    cbref= sv_newmortal();
    opaqueref= sv_newmortal();
    ffref= sv_newmortal();

    sv_setref_pv(cbref, NULL, cb);
    sv_setref_pv(opaqueref, NULL, opaque);
    sv_setref_pv(ffref, NULL, ff);

    PUSHMARK(SP);
    XPUSHs(sv_2mortal(newSViv(fd)));
    XPUSHs(sv_2mortal(newSViv(events)));
    XPUSHs(cbref);
    XPUSHs(opaqueref);
    XPUSHs(ffref);
    PUTBACK;

    ret = call_pv("Sys::Virt::Event::_add_handle", G_SCALAR);

    SPAGAIN;

    if (ret == 1)
      watch = POPi;

    FREETMPS;
    LEAVE;

    if (ret != 1)
      return -1;

    return watch;
}

static void
_event_update_handle(int watch,
		     int events)
{
    dSP;

    ENTER;
    SAVETMPS;

    PUSHMARK(SP);
    XPUSHs(sv_2mortal(newSViv(watch)));
    XPUSHs(sv_2mortal(newSViv(events)));
    PUTBACK;

    call_pv("Sys::Virt::Event::_update_handle", G_DISCARD);

    FREETMPS;
    LEAVE;
}

static int
_event_remove_handle(int watch)
{
    dSP;

    ENTER;
    SAVETMPS;

    PUSHMARK(SP);
    XPUSHs(sv_2mortal(newSViv(watch)));
    PUTBACK;

    call_pv("Sys::Virt::Event::_remove_handle", G_DISCARD);

    FREETMPS;
    LEAVE;

    return 0;
    return 0;
}

static int
_event_add_timeout(int interval,
		   virEventTimeoutCallback cb,
		   void *opaque,
		   virFreeCallback ff)
{
    SV *cbref;
    SV *opaqueref;
    SV *ffref;
    int ret;
    int timer = 0;
    dSP;

    ENTER;
    SAVETMPS;

    cbref = sv_newmortal();
    opaqueref = sv_newmortal();
    ffref = sv_newmortal();

    sv_setref_pv(cbref, NULL, cb);
    sv_setref_pv(opaqueref, NULL, opaque);
    sv_setref_pv(ffref, NULL, ff);

    PUSHMARK(SP);
    XPUSHs(sv_2mortal(newSViv(interval)));
    XPUSHs(cbref);
    XPUSHs(opaqueref);
    XPUSHs(ffref);
    PUTBACK;

    ret = call_pv("Sys::Virt::Event::_add_timeout", G_SCALAR);

    SPAGAIN;

    if (ret == 1)
      timer = POPi;

    FREETMPS;
    LEAVE;

    if (ret != 1)
      return -1;

    return timer;
}

static void
_event_update_timeout(int timer,
		      int interval)
{
    dSP;

    ENTER;
    SAVETMPS;

    PUSHMARK(SP);
    XPUSHs(sv_2mortal(newSViv(timer)));
    XPUSHs(sv_2mortal(newSViv(interval)));
    PUTBACK;

    call_pv("Sys::Virt::Event::_update_timeout", G_DISCARD);

    FREETMPS;
    LEAVE;
}

static int
_event_remove_timeout(int timer)
{
    dSP;

    ENTER;
    SAVETMPS;

    PUSHMARK(SP);
    XPUSHs(sv_2mortal(newSViv(timer)));
    PUTBACK;

    call_pv("Sys::Virt::Event::_remove_timeout", G_DISCARD);

    FREETMPS;
    LEAVE;

    return 0;
}


static int
_open_auth_callback(virConnectCredentialPtr cred,
		    unsigned int ncred,
		    void *cbdata)
{
  dSP;
  int i, ret, success = -1;
  AV *credlist;

  credlist = newAV();

  ENTER;
  SAVETMPS;
  PUSHMARK(SP);

  for (i = 0 ; i < ncred ; i++) {
      HV *credrec = newHV();

      (void)hv_store(credrec, "type", 4, newSViv(cred[i].type), 0);
      (void)hv_store(credrec, "prompt", 6, newSVpv(cred[i].prompt, 0), 0);
      (void)hv_store(credrec, "challenge", 9, newSVpv(cred[i].challenge, 0), 0);
      (void)hv_store(credrec, "result", 6, newSVpv(cred[i].defresult, 0), 0);

      av_push(credlist, newRV_noinc((SV *)credrec));
  }
  SvREFCNT_inc((SV*)credlist);

  XPUSHs(newRV_noinc((SV*)credlist));
  PUTBACK;

  ret = call_sv((SV*)cbdata, G_SCALAR);

  SPAGAIN;

  if (ret == 1)
     success = POPi;

  for (i = 0 ; i < ncred ; i++) {
      SV **credsv = av_fetch(credlist, i, 0);
      HV *credrec = (HV*)SvRV(*credsv);
      SV **val = hv_fetch(credrec, "result", 6, 0);

      if (val && SvOK(*val)) {
	  STRLEN len;
	  char *result = SvPV(*val, len);
	  if (!(cred[i].result = malloc(len+1)))
	      abort();
	  memcpy(cred[i].result, result, len+1);
	  cred[i].resultlen = (unsigned int)len;
      } else {
	  cred[i].resultlen = 0;
	  cred[i].result = NULL;
      }
  }

  FREETMPS;
  LEAVE;

  return success;
}


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


virConnectPtr
_open_auth(name, readonly, creds, cb)
      const char *name;
      int readonly;
      SV *creds;
      SV *cb;
PREINIT:
      AV *credlist;
      virConnectAuth auth;
      int i;
   CODE:
      if (SvOK(cb) && SvOK(creds)) {
	  memset(&auth, 0, sizeof auth);
	  credlist = (AV*)SvRV(creds);
	  auth.ncredtype = av_len(credlist) + 1;
	  Newx(auth.credtype, auth.ncredtype, int);
	  for (i = 0 ; i < auth.ncredtype ; i++) {
	    SV **type = av_fetch(credlist, i, 0);
	    auth.credtype[i] = SvIV(*type);
	  }

	  auth.cb = _open_auth_callback;
	  auth.cbdata = cb;
	  RETVAL = virConnectOpenAuth(name,
				      &auth,
				      readonly ? VIR_CONNECT_RO : 0);
      } else {
	  RETVAL = virConnectOpenAuth(name,
				      virConnectAuthPtrDefault,
				      readonly ? VIR_CONNECT_RO : 0);
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
      RETVAL = (HV *)sv_2mortal((SV*)newHV());
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
      RETVAL = (HV *)sv_2mortal((SV*)newHV());
      (void)hv_store (RETVAL, "model", 5, newSVpv(secmodel.model, 0), 0);
      (void)hv_store (RETVAL, "doi", 3, newSVpv(secmodel.doi, 0), 0);
   OUTPUT:
      RETVAL

SV *
get_node_free_memory(con)
      virConnectPtr con;
PREINIT:
      unsigned long long mem;
   CODE:
      if ((mem = virNodeGetFreeMemory(con)) == 0) {
	_croak_error(virConnGetLastError(con));
      }
      RETVAL = virt_newSVull(mem);
  OUTPUT:
      RETVAL


void
get_node_cells_free_memory(con, start, end)
      virConnectPtr con;
      int start;
      int end;
PREINIT:
      unsigned long long *mem;
      int i, num;
 PPCODE:
      Newx(mem, end-start, unsigned long long);
      if ((num = virNodeGetCellsFreeMemory(con, mem, start, end)) < 0) {
	Safefree(mem);
	_croak_error(virConnGetLastError(con));
      }
      EXTEND(SP, num);
      for (i = 0 ; i < num ; i++) {
	SV *val = newSViv(mem[i]);
	PUSHs(sv_2mortal(val));
      }
      Safefree(mem);


char *
find_storage_pool_sources(con, type, srcspec, flags)
      virConnectPtr con;
      const char *type;
      const char *srcspec;
      unsigned int flags;
    CODE:
      if ((RETVAL = virConnectFindStoragePoolSources(con, type, srcspec, flags)) == NULL) {
	_croak_error(virConnGetLastError(con));
      }
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
domain_event_register(conref, cb)
      SV* conref;
      SV* cb;
PREINIT:
      AV *opaque;
      virConnectPtr con;
 PPCODE:
      con = (virConnectPtr)SvIV((SV*)SvRV(conref));
      opaque = newAV();
      SvREFCNT_inc(cb);
      SvREFCNT_inc(conref);
      av_push(opaque, conref);
      av_push(opaque, cb);
      virConnectDomainEventRegister(con, _domain_event_callback, opaque, _domain_event_free);

void
domain_event_deregister(con)
      virConnectPtr con;
 PPCODE:
      virConnectDomainEventDeregister(con, _domain_event_callback);

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
      RETVAL = virDomainGetID(dom);
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
      RETVAL = (HV *)sv_2mortal((SV*)newHV());
      (void)hv_store (RETVAL, "state", 5, newSViv(info.state), 0);
      (void)hv_store (RETVAL, "maxMem", 6, newSViv(info.maxMem), 0);
      (void)hv_store (RETVAL, "memory", 6, newSViv(info.memory), 0);
      (void)hv_store (RETVAL, "nrVirtCpu", 9, newSViv(info.nrVirtCpu), 0);
      (void)hv_store (RETVAL, "cpuTime", 7, virt_newSVull(info.cpuTime), 0);
  OUTPUT:
      RETVAL


HV *
get_scheduler_parameters(dom)
      virDomainPtr dom;
  PREINIT:
      virSchedParameter *params;
      int nparams;
      unsigned int i;
      char *type;
    CODE:
      if (!(type = virDomainGetSchedulerType(dom, &nparams))) {
	_croak_error(virConnGetLastError(virDomainGetConnect(dom)));
      }
      free(type);
      Newx(params, nparams, virSchedParameter);
      if (virDomainGetSchedulerParameters(dom, params, &nparams) < 0) {
	_croak_error(virConnGetLastError(virDomainGetConnect(dom)));
      }
      RETVAL = (HV *)sv_2mortal((SV*)newHV());
      for (i = 0 ; i < nparams ; i++) {
	SV *val = NULL;

	switch (params[i].type) {
	case VIR_DOMAIN_SCHED_FIELD_INT:
	  val = newSViv(params[i].value.i);
	  break;

	case VIR_DOMAIN_SCHED_FIELD_UINT:
	  val = newSViv((int)params[i].value.ui);
	  break;

	case VIR_DOMAIN_SCHED_FIELD_LLONG:
	  val = virt_newSVll(params[i].value.l);
	  break;

	case VIR_DOMAIN_SCHED_FIELD_ULLONG:
	  val = virt_newSVull(params[i].value.ul);
	  break;

	case VIR_DOMAIN_SCHED_FIELD_DOUBLE:
	  val = newSVnv(params[i].value.d);
	  break;

	case VIR_DOMAIN_SCHED_FIELD_BOOLEAN:
	  val = newSViv(params[i].value.b);
	  break;
	}

	(void)hv_store (RETVAL, params[i].field, strlen(params[i].field), val, 0);
      }
  OUTPUT:
      RETVAL

void
set_scheduler_parameters(dom, newparams)
      virDomainPtr dom;
      HV *newparams;
  PREINIT:
      virSchedParameter *params;
      int nparams;
      unsigned int i;
      char *type;
    PPCODE:
      if (!(type = virDomainGetSchedulerType(dom, &nparams))) {
	_croak_error(virConnGetLastError(virDomainGetConnect(dom)));
      }
      free(type);
      Newx(params, nparams, virSchedParameter);
      if (virDomainGetSchedulerParameters(dom, params, &nparams) < 0) {
	_croak_error(virConnGetLastError(virDomainGetConnect(dom)));
      }
      for (i = 0 ; i < nparams ; i++) {
	SV **val;

	if (!hv_exists(newparams, params[i].field, strlen(params[i].field)))
	  continue;

	val = hv_fetch (newparams, params[i].field, strlen(params[i].field), 0);

	switch (params[i].type) {
	case VIR_DOMAIN_SCHED_FIELD_INT:
	  params[i].value.i = SvIV(*val);
	  break;

	case VIR_DOMAIN_SCHED_FIELD_UINT:
	  params[i].value.ui = SvIV(*val);
	  break;

	case VIR_DOMAIN_SCHED_FIELD_LLONG:
	  params[i].value.l = virt_SvIVll(*val);
	  break;

	case VIR_DOMAIN_SCHED_FIELD_ULLONG:
	  params[i].value.ul = virt_SvIVull(*val);
	  break;

	case VIR_DOMAIN_SCHED_FIELD_DOUBLE:
	  params[i].value.d = SvNV(*val);
	  break;

	case VIR_DOMAIN_SCHED_FIELD_BOOLEAN:
	  params[i].value.b = SvIV(*val);
	  break;
	}

      }
      if (virDomainSetSchedulerParameters(dom, params, nparams) < 0) {
	_croak_error(virConnGetLastError(virDomainGetConnect(dom)));
      }


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
   CODE:
     if ((RETVAL = virDomainMigrate(dom, destcon, flags, dname, uri, bandwidth)) == NULL) {
       _croak_error(virConnGetLastError(virDomainGetConnect(dom)));
     }
 OUTPUT:
     RETVAL

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
      RETVAL = (HV *)sv_2mortal((SV*)newHV());
      (void)hv_store (RETVAL, "rd_req", 6, virt_newSVll(stats.rd_req), 0);
      (void)hv_store (RETVAL, "rd_bytes", 8, virt_newSVll(stats.rd_bytes), 0);
      (void)hv_store (RETVAL, "wr_req", 6, virt_newSVll(stats.wr_req), 0);
      (void)hv_store (RETVAL, "wr_bytes", 8, virt_newSVll(stats.wr_bytes), 0);
      (void)hv_store (RETVAL, "errs", 4, virt_newSVll(stats.errs), 0);
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
      RETVAL = (HV *)sv_2mortal((SV*)newHV());
      (void)hv_store (RETVAL, "rx_bytes", 8, virt_newSVll(stats.rx_bytes), 0);
      (void)hv_store (RETVAL, "rx_packets", 10, virt_newSVll(stats.rx_packets), 0);
      (void)hv_store (RETVAL, "rx_errs", 7, virt_newSVll(stats.rx_errs), 0);
      (void)hv_store (RETVAL, "rx_drop", 7, virt_newSVll(stats.rx_drop), 0);
      (void)hv_store (RETVAL, "tx_bytes", 8, virt_newSVll(stats.tx_bytes), 0);
      (void)hv_store (RETVAL, "tx_packets", 10, virt_newSVll(stats.tx_packets), 0);
      (void)hv_store (RETVAL, "tx_errs", 7, virt_newSVll(stats.tx_errs), 0);
      (void)hv_store (RETVAL, "tx_drop", 7, virt_newSVll(stats.tx_drop), 0);
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
      RETVAL = (HV *)sv_2mortal((SV*)newHV());
      (void)hv_store (RETVAL, "label", 5, newSVpv(seclabel.label, 0), 0);
      (void)hv_store (RETVAL, "enforcing", 9, newSViv(seclabel.enforcing), 0);
   OUTPUT:
      RETVAL


void
get_vcpu_info(dom)
      virDomainPtr dom;
 PREINIT:
      virVcpuInfoPtr info;
      unsigned char *cpumaps;
      int maplen;
      virNodeInfo nodeinfo;
      virDomainInfo dominfo;
      int nvCpus;
      int i;
   PPCODE:
      if (virNodeGetInfo(virDomainGetConnect(dom), &nodeinfo) < 0) {
	_croak_error(virConnGetLastError(virDomainGetConnect(dom)));
      }
      if (virDomainGetInfo(dom, &dominfo) < 0) {
	_croak_error(virConnGetLastError(virDomainGetConnect(dom)));
      }

      Newx(info, dominfo.nrVirtCpu, virVcpuInfo);
      maplen = VIR_CPU_MAPLEN(VIR_NODEINFO_MAXCPUS(nodeinfo));
      Newx(cpumaps, dominfo.nrVirtCpu * maplen, unsigned char);
      if ((nvCpus = virDomainGetVcpus(dom, info, dominfo.nrVirtCpu, cpumaps, maplen)) < 0) {
	Safefree(info);
	Safefree(cpumaps);
	_croak_error(virConnGetLastError(virDomainGetConnect(dom)));
      }

      EXTEND(SP, nvCpus);
      for (i = 0 ; i < nvCpus ; i++) {
	HV *rec = newHV();
	(void)hv_store(rec, "number", 6, newSViv(info[i].number), 0);
	(void)hv_store(rec, "state", 5, newSViv(info[i].state), 0);
	(void)hv_store(rec, "cpuTime", 7, virt_newSVull(info[i].cpuTime), 0);
	(void)hv_store(rec, "cpu", 3, newSViv(info[i].cpu), 0);
	(void)hv_store(rec, "affinity", 8, newSVpvn((char*)cpumaps + (i *maplen), maplen), 0);
	PUSHs(newRV_noinc((SV *)rec));
      }

      Safefree(info);
      Safefree(cpumaps);


void
pin_vcpu(dom, vcpu, mask)
     virDomainPtr dom;
     unsigned int vcpu;
     SV *mask;
PREINIT:
     STRLEN masklen;
     unsigned char *maps;
 PPCODE:
     maps = (unsigned char *)SvPV(mask, masklen);
     if (virDomainPinVcpu(dom, vcpu, maps, masklen) < 0) {
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
      RETVAL = (HV *)sv_2mortal((SV*)newHV());
      (void)hv_store (RETVAL, "state", 5, newSViv(info.state), 0);
      (void)hv_store (RETVAL, "capacity", 8, virt_newSVull(info.capacity), 0);
      (void)hv_store (RETVAL, "allocation", 10, virt_newSVull(info.allocation), 0);
      (void)hv_store (RETVAL, "available", 9, virt_newSVull(info.available), 0);
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
      RETVAL = (HV *)sv_2mortal((SV*)newHV());
      (void)hv_store (RETVAL, "type", 4, newSViv(info.type), 0);
      (void)hv_store (RETVAL, "capacity", 8, virt_newSVull(info.capacity), 0);
      (void)hv_store (RETVAL, "allocation", 10, virt_newSVull(info.allocation), 0);
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

MODULE = Sys::Virt::Event  PACKAGE = Sys::Virt::Event

PROTOTYPES: ENABLE

void
_register_impl()
 PPCODE:
      virEventRegisterImpl(_event_add_handle,
			   _event_update_handle,
			   _event_remove_handle,
			   _event_add_timeout,
			   _event_update_timeout,
			   _event_remove_timeout);

void
_run_handle_callback_helper(watch, fd, event, cbref, opaqueref)
      int watch;
      int fd;
      int event;
      SV *cbref;
      SV *opaqueref;
 PREINIT:
      virEventHandleCallback cb;
      void *opaque;
  PPCODE:
      cb = (virEventHandleCallback)SvIV((SV*)SvRV(cbref));
      opaque = (void*)SvIV((SV*)SvRV(opaqueref));

      cb(watch, fd, event, opaque);


void
_run_timeout_callback_helper(timer, cbref, opaqueref)
      int timer;
      SV *cbref;
      SV *opaqueref;
 PREINIT:
      virEventTimeoutCallback cb;
      void *opaque;
  PPCODE:
      cb = (virEventTimeoutCallback)SvIV((SV*)SvRV(cbref));
      opaque = (void*)SvIV((SV*)SvRV(opaqueref));

      cb(timer, opaque);


void
_free_callback_opaque_helper(ffref, opaqueref)
      SV *ffref;
      SV *opaqueref;
PREINIT:
      virFreeCallback ff;
      void *opaque;
  PPCODE:
      opaque = SvOK(opaqueref) ? (void*)SvIV((SV*)SvRV(opaqueref)) : NULL;
      ff = SvOK(ffref) ? (virFreeCallback)SvIV((SV*)SvRV(ffref)) : NULL;

      if (opaque != NULL && ff != NULL)
        ff(opaque);



MODULE = Sys::Virt  PACKAGE = Sys::Virt


PROTOTYPES: ENABLE


BOOT:
    {
      HV *stash;

      virSetErrorFunc(NULL, ignoreVirErrorFunc);

      stash = gv_stashpv( "Sys::Virt", TRUE );

      /*
       * Not required
      RGISTER_CONSTANT(VIR_CONNECT_RO, CONNECT_RO);
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


      stash = gv_stashpv( "Sys::Virt::Event", TRUE );

      REGISTER_CONSTANT(VIR_EVENT_HANDLE_READABLE, HANDLE_READABLE);
      REGISTER_CONSTANT(VIR_EVENT_HANDLE_WRITABLE, HANDLE_WRITABLE);
      REGISTER_CONSTANT(VIR_EVENT_HANDLE_ERROR, HANDLE_ERROR);
      REGISTER_CONSTANT(VIR_EVENT_HANDLE_HANGUP, HANDLE_HANGUP);


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
