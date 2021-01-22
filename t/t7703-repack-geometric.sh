#!/bin/sh

test_description='git repack --geometric works correctly'

. ./test-lib.sh

GIT_TEST_MULTI_PACK_INDEX=0

objdir=.git/objects
midx=$objdir/pack/multi-pack-index

test_expect_success '--geometric with an intact progression' '
	git init geometric &&
	test_when_finished "rm -fr geometric" &&
	(
		cd geometric &&

		# These packs already form a geometric progression.
		test_commit_bulk --start=1 1 && # 3 objects
		test_commit_bulk --start=2 2 && # 6 objects
		test_commit_bulk --start=4 4 && # 12 objects

		find $objdir/pack -name "*.pack" | sort >expect &&
		GIT_TEST_MULTI_PACK_BITMAP=0 git repack --geometric 2 -d &&
		find $objdir/pack -name "*.pack" | sort >actual &&

		test_cmp expect actual
	)
'

test_expect_success '--geometric with small-pack rollup' '
	git init geometric &&
	test_when_finished "rm -fr geometric" &&
	(
		cd geometric &&

		test_commit_bulk --start=1 1 && # 3 objects
		test_commit_bulk --start=2 1 && # 3 objects
		find $objdir/pack -name "*.pack" | sort >small &&
		test_commit_bulk --start=3 4 && # 12 objects
		test_commit_bulk --start=7 8 && # 24 objects
		find $objdir/pack -name "*.pack" | sort >before &&

		GIT_TEST_MULTI_PACK_BITMAP=0 git repack --geometric 2 -d &&

		# Three packs in total; two of the existing large ones, and one
		# new one.
		find $objdir/pack -name "*.pack" | sort >after &&
		test_line_count = 3 after &&
		comm -3 small before | tr -d "\t" >large &&
		grep -qFf large after
	)
'

test_expect_success '--geometric with small- and large-pack rollup' '
	git init geometric &&
	test_when_finished "rm -fr geometric" &&
	(
		cd geometric &&

		# size(small1) + size(small2) > size(medium) / 2
		test_commit_bulk --start=1 1 && # 3 objects
		test_commit_bulk --start=2 1 && # 3 objects
		test_commit_bulk --start=2 3 && # 7 objects
		test_commit_bulk --start=6 9 && # 27 objects &&

		find $objdir/pack -name "*.pack" | sort >before &&

		GIT_TEST_MULTI_PACK_BITMAP=0 git repack --geometric 2 -d &&

		find $objdir/pack -name "*.pack" | sort >after &&
		comm -12 before after >untouched &&

		# Two packs in total; the largest pack from before running "git
		# repack", and one new one.
		test_line_count = 1 untouched &&
		test_line_count = 2 after
	)
'

test_done
