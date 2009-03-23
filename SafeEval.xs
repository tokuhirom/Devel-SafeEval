#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"
#ifdef __cplusplus
}
#endif

static HV * c;
Perl_ppaddr_t orig_unpack;

#define GET_CV(assigned_to, name) do { \
        SV ** xsubref = hv_fetch(c, name, strlen(name), 0); \
        assert(xsubref); \
        assigned_to = SvRV(*xsubref); \
        assert(xsub); \
        assert(SvTYPE(*xsub) == SVt_PVCV); \
    } while (0)

OP * safeeval_unpack_wrapper(pTHX) {
    dAXMARK;
    if (SvPOK(ST(0))) {
        const char* buf = SvPV_nolen(ST(0));
        if (strchr(buf, 'p')) {
            Perl_croak(aTHX_ "unpack 'p' is not allowed");
        }
        ST(0) = sv_2mortal(newSVpv(buf, strlen(buf)));
        return orig_unpack(aTHX);
    } else {
        Perl_croak(aTHX_ "invalid type");
    }
}

MODULE = Devel::SafeEval  PACKAGE = Devel::SafeEval::Defender

PROTOTYPES: DISABLE

void
setup(HV* _c)
CODE:
    SvREFCNT_inc(_c);
    orig_unpack = PL_ppaddr[OP_UNPACK];
    PL_ppaddr[OP_UNPACK] = safeeval_unpack_wrapper;
    c = _c;

CV*
load(const char*_module, const char*_bootstrap_method)
CODE:
    dSP;

    SV * boot_symref;
    SV * libref;
    SV * filename;
    SV * bootname;
    SV * module = sv_2mortal(newSVpv(_module, strlen(_module)));
    SV * bootstrap_method = sv_2mortal(newSVpv(_bootstrap_method, strlen(_bootstrap_method)));

    /* setup_mod */
    {
        /*
        my ($filename, $bootname) = $setup_mod->( $module );
        */
        SV * setup_mod;
        GET_CV(setup_mod, "setup_mod");
        {
            ENTER;
            SAVETMPS;

            PUSHMARK(sp);
            XPUSHs(module);
            PUTBACK;

            call_sv((SV*)setup_mod, G_ARRAY);
            SPAGAIN;
            {
                SV* ret = POPs;
                SvREFCNT_inc(ret);
                assert(ret);
                bootname = ret;
            }
            {
                SV* ret = POPs;
                SvREFCNT_inc(ret);
                assert(ret);
                filename = ret;
            }
            PUTBACK;

            FREETMPS;
            LEAVE;
        }
    }

    /* trusted check */
    {
        SV ** trusted_ref = hv_fetch(c, "trusted", strlen("trusted"), 0);
        assert(trusted_ref);
        assert(SvROK(*trusted));
        assert(SvTYPE(SvRV(*trusted)) == SVt_PVHV);
        HV * trusted = (HV*)SvRV(*trusted_ref);
        bool is_trusted = hv_exists(trusted, (char*)SvPV_nolen(module), sv_len(module));
        if (!is_trusted) {
            Perl_croak(aTHX_ "untrusted module %s", SvPV_nolen(module));
        }
    }

    /* dl_load_file */
    {
        /*
        my $libref = $dl_load_file->( $file, 0 ) or do {
            die "Can't load '$file' for module $module: " . $dl_error->();
        };
        */
        SV * dl_load_file;
        GET_CV(dl_load_file, "dl_load_file");
        {
            ENTER;
            SAVETMPS;

            PUSHMARK(sp);
            XPUSHs(filename);
            XPUSHs(sv_2mortal(newSViv(0)));
            PUTBACK;

            call_sv((SV*)dl_load_file, G_SCALAR);
            SPAGAIN;
            SV* ret = POPs;
            SvREFCNT_inc(ret);
            assert(ret);
            libref = ret;
            PUTBACK;

            FREETMPS;
            LEAVE;
        }
    }

    /* dl_find_symbol */
    {
        /*
        my $boot_symbol_ref = $dl_find_symbol->( $libref, $bootname ) or do {
            die "Can't find '$bootname' symbol in $file\n";
        };
        */
        SV * dl_find_symbol;
        GET_CV(dl_find_symbol, "dl_find_symbol");
        {
            ENTER;
            SAVETMPS;

            PUSHMARK(sp);
            XPUSHs(libref);
            XPUSHs(bootname);
            PUTBACK;

            call_sv((SV*)dl_find_symbol, G_SCALAR);
            SPAGAIN;
            SV* ret = POPs;
            SvREFCNT_inc(ret);
            assert(ret);
            boot_symref = ret;
            PUTBACK;

            FREETMPS;
            LEAVE;
        }
    }

    /* dl_install_xsub */
    {
        /*
        my $xs = $dl_install_xsub->( "${module}::bootstrap", $boot_symbol_ref,
            $file );
        */
        SV * dl_install_xsub;
        GET_CV(dl_install_xsub, "dl_install_xsub");
        {
            ENTER;
            SAVETMPS;

            PUSHMARK(sp);
            XPUSHs(bootstrap_method);
            XPUSHs(boot_symref);
            XPUSHs(filename);
            PUTBACK;

            call_sv((SV*)dl_install_xsub, G_SCALAR);
            SPAGAIN;
            SV* retref = POPs;
            SV*ret = SvRV(retref);
            assert(SvTYPE(ret) == SVt_PVCV);
            RETVAL = (CV*)ret;
            PUTBACK;

            FREETMPS;
            LEAVE;
        }
    }
OUTPUT:
    RETVAL

