# Makefile for National Early Rollout website.
#
# Automates the creation of the website that contains the 4 Basic Induction
# Packages for Newly Qualified Teachers. The content is supplied by DfE
# suppliers and uplifted for publication by DfE Content Designers using the
# Knowbly authoring package.
#
#
# Andy Bennett <andyjpb@digital.education.gov.uk>, 2020/06
#

CF=bin/cf

SRCS=$(shell find src -type f -name \*.zip)
DISTS=$(patsubst src/%.zip,dist/%,$(SRCS))

SERVICE=ecf-bips
WHOAMI=$(shell whoami)
MY_DEPLOY=$(SERVICE)-$(WHOAMI)
MY_DOMAIN=london.cloudapps.digital
LIVE_DEPLOY=$(SERVICE)
LIVE_DOMAIN=london.cloudapps.digital
RELEASE_TAG=release-$(shell TZ=UTC date +%Y-%m-%dT%H-%M-%SZ)
RELEASE_REPO=git@github.com:DFE-Digital/ecf-bips-release.git

CF_PUSH_FLAGS=push -p dist -b staticfile_buildpack -m 64M -k 64M


.PHONY: all help dists browse cf-login cf-check deploy undeploy list-deploys check-src release live clean mrproper


all: dists dist/index.html

help:
	@echo "Early Careers Framework build system for building and deploying the 4 Basic"
	@echo "Induction Packages for Newly Qualified Teachers."
	@echo
	@echo "To get started you probably want to run \`make all browse\` to build everything"
	@echo "and preview it locally."
	@echo
	@echo "Usage:"
	@echo
	@echo " make all"
	@echo "  Build all of the all the Knowbly modules and the index page that lists them."
	@echo
	@echo " make help"
	@echo "  Display this help text."
	@echo
	@echo " make dist"
	@echo "  Create the dist/ directory where the built modules will be put."
	@echo
	@echo " make dists"
	@echo "  Build all of the Knowbly modules."
	@echo
	@echo " make browse"
	@echo "  Open the locally built site in a web browser."
	@echo
	@echo " make cf-login"
	@echo "  Ensure the CloudFoundry configuration is set up properly: log in and set the"
	@echo "  target."
	@echo
	@echo " make cf-check"
	@echo "  Checks that the CloudFoundry login is still valid. This is a helper target for"
	@echo "  the release process. Credentials expire from time-to-time and we don't want to"
	@echo "  cut a release if it'll definitely fail to deploy."
	@echo
	@echo " make deploy"
	@echo "  Deploy everything to GOV.UK PaaS into a a test site for your own use. The"
	@echo "  place that things will be deployed to is documented below and varies for each"
	@echo "  person."
	@echo
	@echo " make undeploy"
	@echo "  Erase your personal test site that was deployed with \`make deploy\`."
	@echo "  You should do this when you are finished with your site so that does not"
	@echo "  consume resources on the GOV.UK PaaS. Your site might be undeployed by someone"
	@echo "  else in the team if you leave it running continuously for several days."
	@echo
	@echo " make list-deploys"
	@echo "  Show all the live sites and test sites that have been deployed by the team."
	@echo
	@echo " make check-src"
	@echo "  Checks that the src/ directory does not have any uncommitted files. This is a"
	@echo "  helper target for the release process."
	@echo
	@echo " make release"
	@echo "  Does a completely clean build, commits it, tags it, pushes it to the release"
	@echo "  repository and then deploys it on the live site."
	@echo
	@echo " make live"
	@echo "  DANGEROUS"
	@echo "  Do a completely clean build, archive this build and then deploy it to the live"
	@echo "  site that will be accessed by the public."
	@echo "  This will completely overwrite the entire live site."
	@echo
	@echo " make clean"
	@echo "  Clean up the builds in the dist/ directory."
	@echo
	@echo " make mrproper"
	@echo "  This does everything that \`make clean\` does and more."
	@echo "  Cleans up temporary files all over the repository but leaves the CloudFoundry"
	@echo "  configuration alone."
	@echo
	@echo
	@echo "Running on:"
	@echo " Machine: $(shell uname -m)"
	@echo " OS:      $(shell uname -s)"
	@echo
	@echo "Source Modules:\n $(patsubst %,%\n,$(SRCS))"
	@echo "Distributable Modules:\n $(patsubst %,%\n,$(DISTS))"
	@echo
	@echo "Personal Deploy to:\n https://${MY_DEPLOY}.${MY_DOMAIN}/"
	@echo
	@echo "Live Deploy to:\n https://${LIVE_DEPLOY}.${LIVE_DOMAIN}/"

dist:
	mkdir dist/

dists: dists.mak dist $(DISTS)

dist/index.html: dist $(SRCS)
	find src -type f | bin/mkindex > $@

browse: dist
	if [ -e dist/index.html ]; then bin/open dist/index.html; else bin/open dist/; fi

cf/.cf/config.json:
	${CF} login -a api.london.cloud.service.gov.uk
	${CF} target -o dfe-digital -s early-careers-framework

cf-login:
	${CF} login -a api.london.cloud.service.gov.uk
	${CF} target -o dfe-digital -s early-careers-framework

cf-check:
	${CF} apps > /dev/null || (echo "\n\nGOV.UK PaaS Authentication has expired. Please run \`make cf-login\` to log in again.\n" ; exit 1)

deploy: cf/.cf/config.json cf-check dist
	${CF} ${CF_PUSH_FLAGS} -d $(MY_DOMAIN) ${MY_DEPLOY}
	@echo
	@echo
	@echo "================================================================================"
	@echo
	@echo "Deployed:"
	@echo " https://$(MY_DEPLOY).$(MY_DOMAIN)"

undeploy: cf/.cf/config.json cf-check
	${CF} delete -f ${MY_DEPLOY}

list-deploys: cf/.cf/config.json
	${CF} apps

check-src:
	git status -s src/ | bin/check-empty "There are uncommitted files in the src/ directory. Please commit your changes and try again." || (git status src/ ; exit 1)

release: check-src mrproper all dist
	# Commit the dists
	git add dist/
	git commit -m "Distributable versions of the modules"
	# Check that the repository is clean
	git status -s | bin/check-empty "There are uncommittted files in the repository that may have affected the integrity of the build!" || (git reset HEAD^ ; git status ; exit 1)
	# Tag and push the release
	git tag ${RELEASE_TAG}
	git push ${RELEASE_REPO} ${RELEASE_TAG} || (git reset HEAD^ ; git tag -d ${RELEASE_TAG} ; exit 1)
	# Move the branch back to where it was so that the release commit is on a branch of its own.
	git reset HEAD^

live: cf/.cf cf-check release
	${CF} ${CF_PUSH_FLAGS} -d $(LIVE_DOMAIN) ${LIVE_DEPLOY}
	@echo
	@echo
	@echo "================================================================================"
	@echo
	@echo "Deployed:"
	@echo " https://$(LIVE_DEPLOY).$(LIVE_DOMAIN)"

clean:
	rm -fr $(DISTS)
	rm -f dist/index.html

mrproper: clean
	rm -f bin/*~ ./*~
	rm -f dists.mak
	if [ -d dist/ ]; then rmdir dist/; fi

dists.mak: $(SRCS)
	find src -type f | bin/mkdists > $@

ifneq ($(MAKECMDGOALS),undeploy)
ifneq ($(MAKECMDGOALS),list-deploys)
ifneq ($(MAKECMDGOALS),clean)
ifneq ($(MAKECMDGOALS),mrproper)
include dists.mak
endif
endif
endif
endif

