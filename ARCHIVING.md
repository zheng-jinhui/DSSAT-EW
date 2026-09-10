# Public archiving checklist

Before creating the submission release:

1. Run workflows 01--04 from the repository root with the manuscript inputs.
2. Confirm that `models/` contains every fitted `.rds` object and
   `model_manifest.csv`; these files are intentionally not ignored by Git.
3. Run `Rscript tests/run_tests.R` and retain the successful console log.
4. Confirm that configuration, input provenance, units and software versions
   match the submitted manuscript.
5. Create an immutable GitHub release, archive that release in Zenodo, and add
   the resulting version-specific DOI to the manuscript and this README.
6. Test the DOI archive in a clean directory. It must not depend on private
   absolute paths.

The DOI-bearing archive includes the trained `.rds` files together with their
checksums and the corresponding configuration and documentation.
