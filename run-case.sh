#!/bin/bash
#
#======================================================================
#=========      Self-Contained OpenFOAM Simulation Script     =========
#======================================================================
set -x # Print every command before it runs (DEBUG FLAG)
#set -e # We are disabling this to see the full error (DEBUG FLAG)

# --- 1. Environment Setup ---
echo "--- DEBUG: Sourcing self-contained OpenFOAM-7 environment..."
# Allow to run as root in OpenMPI
export OMPI_ALLOW_RUN_AS_ROOT=1
export OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1

# Source the bashrc from our compiled-in path
source /opt/OpenFOAM/OpenFOAM-7/etc/bashrc
. "$WM_PROJECT_DIR/bin/tools/RunFunctions"
. "$WM_PROJECT_DIR/bin/tools/CleanFunctions"

# Allow dynamic code execution as admin (root)
export FOAM_ALLOW_ADMIN_EXEC=1
echo "--- DEBUG: Environment sourced."

# --- 2. Configuration ---
NPROCS=${NPROCS:-4}
echo "--- DEBUG: Running job in: $(pwd)"
echo "--- DEBUG: Using $NPROCS processors for parallel execution."

# --- 3. Pre-processing & Meshing ---
echo "--- DEBUG: Starting pre-processing and meshing..."
echo "--- DEBUG: Cleaning the case directory..."
# # Remove surface and features
# rm -f constant/triSurface/BYOG.stl > /dev/null 2>&1
# rm -rf constant/extendedFeatureEdgeMesh > /dev/null 2>&1
# rm -f constant/triSurface/BYOG.eMesh > /dev/null 2>&1
cleanCase

echo "--- DEBUG: Updating decomposeParDict for $NPROCS subdomains..."
sed -i "s/numberOfSubdomains [0-9][0-9]*;/numberOfSubdomains $NPROCS;/" system/decomposeParDict

echo "--- DEBUG: Running runApplication surfaceFeatures..."
runApplication surfaceFeatures

echo "--- DEBUG: Running runApplication blockMesh..."
runApplication blockMesh
echo "--- DEBUG: Running runApplication decomposePar -copyZero..."
runApplication decomposePar -copyZero

echo "--- DEBUG: Running runParallel snappyHexMesh -overwrite..."
runParallel snappyHexMesh -overwrite

echo "--- DEBUG: Visualizing mesh ..."
#runApplication foamToVTK

# --- 4. Running The Solver ---
echo "--- DEBUG: Initializing flow field and running the solver..."
runParallel patchSummary
runParallel potentialFoam
runParallel "$(getApplication)"

# --- 5. Post-processing ---
echo "--- DEBUG: Reconstructing the case..."
runApplication reconstructParMesh -constant
runApplication reconstructPar
runApplication foamToVTK

echo "Simulation finished successfully. ✅"