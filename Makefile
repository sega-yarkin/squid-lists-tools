
.DEFAULT_GOAL := do-all
.PHONY : build-all build-go build-go-in-docker clean-bin clean-all do-all
.PHONY : download-lists filter-ips filter-blogs filter-known filter-nx generate-lists

GO_PROJECTS = filter-ip httx dnx
GO_VERSION = 1.15
ALPINE_VERSION = 3.12

.bin:
	mkdir .bin 2>/dev/null || :

.bin/%: .bin
	@echo "Building $*..."
	cd $* && go build && cd ..
	mv $*/$* .bin/

build-go: $(GO_PROJECTS:%=.bin/%)

build-go-in-docker: .bin
	docker run --rm \
		-v "$(PWD)":/srv -w /srv \
		"golang:$(GO_VERSION)-alpine" \
		/srv/build.sh $(GO_PROJECTS)

build-all: .bin build-go-in-docker

clean-bin:
	rm -f .bin/*

clean-all: clean-bin
	rm -rf lists

define run_in_docker
	docker run -it --rm \
		-v $(PWD):/srv -w /srv alpine:$(ALPINE_VERSION) \
		/srv/$(1)
endef


# STEP 0
download-lists:
	@$(call run_in_docker,download-lists.sh)

# STEP 1
filter-ips:
	@$(call run_in_docker,filter-ips.sh)

# STEP 2
filter-blogs:
	@$(call run_in_docker,filter-blogs.sh)

# STEP 3
filter-known:
	@$(call run_in_docker,filter-known.sh)

# STEP 4
filter-nx:
	@$(call run_in_docker,filter-nx-dns.sh)

# STEP 5
generate-lists:
	@$(call run_in_docker,generate-lists.sh)


do-all: clean-all build-all download-lists filter-ips filter-blogs filter-known filter-nx generate-lists

# NOTES
# Squid list types:
# 1) dst, ip-address/mask
# 2) dstdomain, .domain.name
# 3) dstdom_regex [is fast], (^|\.)domain\.com$

