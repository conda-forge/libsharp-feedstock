#!/bin/bash

set -e

autoconf

config_mpi=""
if [ "x$mpi" = "xnompi" ]; then
    export CC=$(basename ${CC})
else
    export CC=mpicc
    export LIBSHARP_MPI=1
    config_mpi="--enable-mpi"
fi

./configure ${config_mpi} \
--enable-openmp \
--enable-noisy-make \
--enable-pic \
--prefix="${PREFIX}"

make -j${CPU_COUNT}

# Do the install by hand (not included in package)
mkdir -p ${PREFIX}/include
mkdir -p ${PREFIX}/lib
mkdir -p ${PREFIX}/bin
cp -R auto/include/* ${PREFIX}/include
cp -R auto/lib/* ${PREFIX}/lib
cp -R auto/bin/* ${PREFIX}/bin

# Manually run the installed tests rather than using
# the "make test" target.  This allows us to control
# the MPI launching of the test commands.

declare -a testcoms=("acctest" "test healpix 2048 -1 1024 -1 0 1" "test fejer1 2047 -1 -1 4096 2 1" "test gauss 2047 -1 -1 4096 0 2")

export OMP_NUM_THREADS=2
if [ "x$mpi" = "xopenmpi" ]; then
    # Using OpenMPI
    for com in "${testcoms[@]}"; do
        echo mpirun --allow-run-as-root \
        --mca btl self,tcp \
        --mca plm isolated \
        --mca rmaps_base_oversubscribe yes \
        --mca btl_vader_single_copy_mechanism none \
        -np 2 sharp_testsuite ${com}
        mpirun --allow-run-as-root \
        --mca btl self,tcp \
        --mca plm isolated \
        --mca rmaps_base_oversubscribe yes \
        --mca btl_vader_single_copy_mechanism none \
        -np 2 sharp_testsuite ${com}
    done
else
    if [ "x$mpi" = "xmpich" ]; then
        # Using MPICH
        for com in "${testcoms[@]}"; do
            export HYDRA_LAUNCHER=fork
            echo mpirun -np 2 sharp_testsuite ${com}
            mpirun -np 2 sharp_testsuite ${com}
        done
    else
        # No MPI
        for com in "${testcoms[@]}"; do
            echo sharp_testsuite ${com}
            sharp_testsuite ${com}
        done
    fi
fi

# Install python bindings
cd python
export LIBSHARP="${PREFIX}"
export LDSHARED="${CC} -shared"
${PYTHON} setup.py install --prefix="${PREFIX}"
