# Runtime assets

CCNux does not redistribute Adobe installers or proprietary Wine runtimes.
At install time, the After Effects service consumes user-provided archives and
can use the existing CCNux runtime assets (`../assets`) when they are present.
This boundary keeps the native application independent from the legacy Python
runtime while preserving the supported offline installation workflow.

