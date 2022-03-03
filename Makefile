MASTODONPP_BUILDDIR = mastodonpp/build
MASTODONPP = $(MASTODONPP_BUILDDIR)/src/libmastodonpp.so

bot: *.nim $(MASTODONPP)
	nim c -d:ssl bot.nim

.PHONY: run
run:
	./bot

$(MASTODONPP): mastodonpp/CMakeLists.txt # includes version
	rm -rf $(MASTODONPP_BUILDDIR)/
	mkdir -p $(MASTODONPP_BUILDDIR)/
	(cd $(MASTODONPP_BUILDDIR)/; cmake ..)
	cmake --build $(MASTODONPP_BUILDDIR) -- -j$(nproc --ignore=1)
	cd -

.PHONY: debug
debug: bot.nim
	nim c --linedir:on --debuginfo --stacktrace:on bot.nim

.PHONY: clean
clean:
	rm -f bot

.PHONY: distclean
distclean: clean
	rm -rf $(MASTODONPP)/build/
