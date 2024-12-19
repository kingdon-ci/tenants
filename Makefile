.PHONY: update apply
update:
	cp -r ../helmreleases/tenant-* ./

apply:
	# Apply manually!
	echo "There is no apply routine, consult the manual"
