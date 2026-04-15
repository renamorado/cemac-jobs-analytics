version 18.0
set more off

/*******************************************************************************
    Purpose:
        Verify that the starter repository structure exists and that the
        current Cameroon data folders are reachable from the project root.

    Inputs:
        Globals created by code/01_setup.do.

    Outputs:
        Console checks only.
*******************************************************************************/

display as text "Running repository structure checks..."

foreach dir in ///
    "${CODEDIR}/01_data_prep" ///
    "${CODEDIR}/02_construct" ///
    "${CODEDIR}/03_analysis" ///
    "${CODEDIR}/04_output" ///
    "${CODEDIR}/05_checks" ///
    "${CAMEROONDIR}/Raw" ///
    "${CAMEROONDIR}/Clean" ///
    "${DATADIR}/WBES_manual" ///
    "${OUTPUTDIR}/tables" ///
    "${OUTPUTDIR}/figures" ///
    "${OUTPUTDIR}/slides" ///
    "${LOGDIR}" ///
    "${MANUSCRIPTDIR}" ///
    "${SLIDESDIR}" {
    assert direxists("`dir'")
}

display as result "Repository directories verified."


