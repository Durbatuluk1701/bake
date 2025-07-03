SLDG_OPAM_REPO_PATH = https://github.com/ku-sldg/opam-repo.git
SLDG_OPAM_REPO_BRANCH = main
SLDG_OPAM_REPO_NAME = ku-sldg/opam-repo

all:	
	dune build

test: all
	dune test

clean:
	dune clean

publish%:
	@echo "\nPublishing to $(SLDG_OPAM_REPO_NAME)\n\n\n"
	@echo "****************************************\nNOTE: Please make sure that the GITHUB TAGGED VERSION and the OPAM TAGGED VERSIONs are the same!\n****************************************\n\n\n"
	opam repo add -a $(SLDG_OPAM_REPO_NAME) $(SLDG_OPAM_REPO_PATH)
	opam publish --repo=$(SLDG_OPAM_REPO_NAME) --target-branch=$(SLDG_OPAM_REPO_BRANCH)

.PHONY:	all 