F77COMP     = ftn 
F90COMP     = ftn 
CCOMP       = cc
LIB_LIST    = -L/global/homes/a/ankitb/local/silo/lib -lsilo -lm 
NICE        =
#OPTS        = -qarch=450 -g -qflttrap=invalid:nanq:zerodivide  
OPTS        = -fast -Mnosecond_underscore 
ARCH        = 
INCLUDE     = -I/global/homes/a/ankitb/local/silo/include

OBJECTS1     = main_mf.o initialize_mpi_nonperiodic.o \
	       define_nonperiodic_mf.o lddrk4_nonperiodic_mf.o grid.o \
               derivCDopt6_sym_tri.o derivCDopt6_asym_tri.o bc_mf.o \
               pproc_mf.o out_mf.o grad_sym.o rhsv_sym_mf.o \
               filters_sym.o filters_asym.o auxiliary_mf.o stats_sym_mf.o \
               hyper_dynamic_sym_mf.o hyper_rhs_sym_mf.o species_rhs_sym.o \
               shock.o tridiagonal.o pentadiagonal.o polydiagonal.o \
               sponge_mf.o vis_silo_mf.o dirs.o pproc_favre.o 

pproc_srm: $(OBJECTS1)
	$(F77COMP) -o pproc_srm $(ARCH) $(OBJECTS1) $(LIB_LIST) 

main_mf.o:  header main_mf.f
	$(F77COMP) -c $(ARCH) $(NICE) $(OPTS) main_mf.f

auxiliary_mf.o: header auxiliary_mf.f
	$(F77COMP) -c $(ARCH) $(NICE) $(OPTS) auxiliary_mf.f
 
define_nonperiodic_mf.o:  header define_nonperiodic_mf.f
	$(F77COMP) -c $(ARCH) $(NICE) $(OPTS) define_nonperiodic_mf.f

filters_sym.o: header LES_header filters_sym.f
	$(F77COMP) -c $(ARCH) $(NICE) $(OPTS) filters_sym.f

filters_asym.o: header LES_header filters_asym.f
	$(F77COMP) -c $(ARCH) $(NICE) $(OPTS) filters_asym.f

grid.o:  header grid.f
	$(F77COMP) -c $(ARCH) $(NICE) $(OPTS) grid.f

derivCDopt6_sym.o:  header derivCDopt6_sym.f
	$(F77COMP) -c $(ARCH) $(NICE) $(OPTS) derivCDopt6_sym.f

derivCDopt6_asym.o:  header derivCDopt6_asym.f
	$(F77COMP) -c $(ARCH) $(NICE) $(OPTS) derivCDopt6_asym.f

derivCDopt6_sym_tri.o: header derivCDopt6_sym_tri.f
	$(F77COMP) -c $(ARCH) $(NICE) $(OPTS) derivCDopt6_sym_tri.f

derivCDopt6_asym_tri.o: header derivCDopt6_asym_tri.f
	$(F77COMP) -c $(ARCH) $(NICE) $(OPTS) derivCDopt6_asym_tri.f

initialize_mpi_nonperiodic.o: header initialize_mpi_nonperiodic.f90
	$(F90COMP) -c $(ARCH) $(NICE) $(OPTS) initialize_mpi_nonperiodic.f90

pentadiagonal.o: pentadiagonal.f90
	$(F90COMP) -c $(ARCH) $(NICE) $(OPTS) pentadiagonal.f90

polydiagonal.o: polydiagonal.f90
	$(F90COMP) -c $(ARCH) $(NICE) $(OPTS) polydiagonal.f90

pproc_mf.o: header pproc_mf.f
	$(F77COMP) -c $(ARCH) $(NICE) $(OPTS) pproc_mf.f

pproc_favre.o: header pproc_favre.f
	$(F77COMP) -c $(ARCH) $(NICE) $(OPTS) pproc_favre.f

tridiagonal.o: tridiagonal.f90
	$(F90COMP) -c $(ARCH) $(NICE) $(OPTS) tridiagonal.f90

stats_sym_mf.o:  header stats_sym_mf.f
	$(F77COMP) -c $(ARCH) $(NICE) $(OPTS) stats_sym_mf.f

out_mf.o:  header out_mf.f
	$(F77COMP) -c $(ARCH) $(NICE) $(OPTS) out_mf.f

grad_sym.o:  header grad_sym.f
	$(F77COMP) -c $(ARCH) $(NICE) $(OPTS) grad_sym.f

hyper_dynamic_sym_mf.o: header LES_header hyper_dynamic_sym_mf.f
	$(F77COMP) -c $(ARCH) $(NICE) $(OPTS) hyper_dynamic_sym_mf.f

hyper_routines_sym_mf.o: header LES_header hyper_routines_sym_mf.f
	$(F77COMP) -c $(ARCH) $(NICE) $(OPTS) hyper_routines_sym_mf.f

hyper_rhs_sym_mf.o: header hyper_rhs_sym_mf.f
	$(F77COMP) -c $(ARCH) $(NICE) $(OPTS) hyper_rhs_sym_mf.f

lddrk4_nonperiodic_mf.o:  header lddrk4_nonperiodic_mf.f
	$(F77COMP) -c $(ARCH) $(NICE) $(OPTS) lddrk4_nonperiodic_mf.f

rhsv_sym_mf.o:  header rhsv_sym_mf.f
	$(F77COMP) -c $(ARCH) $(NICE) $(OPTS) rhsv_sym_mf.f

shock.o: header shock.f
	$(F77COMP) -c $(ARCH) $(NICE) $(OPTS) shock.f

species_rhs_sym.o: header species_rhs_sym.f
	$(F77COMP) -c $(ARCH) $(NICE) $(OPTS) species_rhs_sym.f

sponge_mf.o: header sponge_mf.f
	$(F77COMP) -c $(ARCH) $(NICE) $(OPTS) sponge_mf.f

vis_silo_mf.o: header part_header vis_silo_mf.f
	$(F77COMP) -c $(ARCH) $(NICE) $(OPTS) $(INCLUDE) vis_silo_mf.f

dirs.o: dirs.h dirs.c
	$(CCOMP) -c $(ARCH) dirs.c

#  remove object files
clean:
	rm -f *.o
