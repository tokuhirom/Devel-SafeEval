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

#define GET_CV(assigned_to, name) do { \
        SV ** xsubref = hv_fetch(c, name, strlen(name), 0); \
        assert(xsubref); \
        assigned_to = SvRV(*xsubref); \
        assert(xsub); \
        assert(SvTYPE(*xsub) == SVt_PVCV); \
    } while (0)

MODULE = Devel::SafeEval  PACKAGE = Devel::SafeEval::Defender

void
setup(HV* _c)
CODE:
    SvREFCNT_inc(_c);
    c = _c;

CV*
load(SV *module, SV*libref, SV*bootname, SV*filename)
CODE:
    dSP;

    SV * boot_symref;

    // dl_find_symbol
    {
        /*
        my $boot_symbol_ref = $dl_find_symbol->( $libref, $bootname ) or do {
            die "Can't find '$bootname' symbol in $file\n";
        };
        */
       // boot_symref = POPs;
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

    // dl_install_xsub
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
            XPUSHs(module); //perl_name
            XPUSHs(boot_symref);
            XPUSHs(filename);
            PUTBACK;

            call_sv((SV*)dl_install_xsub, G_SCALAR);
            SPAGAIN;
            SV* retref = POPs;
            SV*ret = SvRV(retref);
            RETVAL = ret;
            PUTBACK;

            FREETMPS;
            LEAVE;
        }
    }
    // Perl_croak(aTHX_ "ahhhh?");
    // Perl_croak(aTHX_ module);
OUTPUT:
    RETVAL

