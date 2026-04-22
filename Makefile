BUILD_MODE=dev
PROCS=0
E3_PYTHON=python
GPRBUILD=gprbuild -j$(PROCS) -p -XBUILD_MODE=$(BUILD_MODE)
KP_JSON=lkql_checker/share/lkql/kp/kp.json
# The documentation requires LKQL's railroad diagrams, default value assumes
# an ANCR environment.
RAILROAD_DIR=$(ANCR_ROOT_DIR_POSIX)/src/langkit-query-language/lkql/build/railroad-diagrams/

all: lkql_checker

lkql_checker: impacts
	$(GPRBUILD) -P lkql_checker/lkql_checker.gpr -p $(GPR_ARGS) -XBUILD_MODE=$(BUILD_MODE)

doc:
	test -d $(RAILROAD_DIR) && echo "GNATcheck RM requires railroad diagrams"
	mkdir -p user_manual/generated && cp -r $(RAILROAD_DIR) user_manual/generated
	cd user_manual && make clean html
	cd lkql_checker/doc && make generate all

impacts:
	[ -f "$(KP_JSON)" ] || "$(E3_PYTHON)" "./utils/impact-db_impacts_gen.py"

format:
	gnatformat -P lkql_checker/lkql_checker.gpr --no-subprojects

test:
	testsuite/testsuite.py -j$(PROCS) -Edtmp

clean: clean_lkql_checker

clean_lkql_checker:
	cd lkql_checker && gprclean
	[ -f "$(KP_JSON)" ] && rm "$(KP_JSON)"

.PHONY: lkql_checker doc impacts format test clean_lkql_checker
