# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop xdg-utils

DESCRIPTION="3D Creation/Animation/Publishing System"
HOMEPAGE="https://www.blender.org"

LICENSE="GPL-3+ Apache-2.0"
SLOT="$(ver_cut 1-2)"

if [[ ${PV} == *9999* ]] ; then
	PROPERTIES="live"
else
	SRC_URI="
		https://download.blender.org/release/Blender${SLOT}/blender-${PV}-linux-x64.tar.xz
	"
	KEYWORDS="~amd64"
fi

IUSE="oneapi"
RESTRICT="strip test"

QA_PREBUILT="opt/${P}/*"

if [[ ${PV} == *9999* ]] ; then
	BDEPEND="
		app-misc/jq
	"
fi

# no := here, this is prebuilt
RDEPEND="
	app-arch/zstd
	media-libs/libglvnd[X]
	sys-libs/glibc
	sys-libs/ncurses
	sys-libs/zlib
	virtual/libcrypt
	x11-base/xorg-server
	x11-libs/libICE
	x11-libs/libSM
	x11-libs/libX11
	x11-libs/libXext
	x11-libs/libXfixes
	x11-libs/libXi
	x11-libs/libXrender
	x11-libs/libXt
	x11-libs/libXxf86vm
	x11-libs/libxkbcommon
	oneapi? (
		dev-libs/level-zero
	)
"

src_unpack() {
	local my_A
	if [[ ${PV} == *9999* ]] ; then
		# TODO what does BLENDER_BIN_URL mean?
		if [[ -n "${BLENDER_BIN_URL}" ]]; then
			einfo "Using ${BLENDER_BIN_URL} as SRC_URI. You are on your own."

			wget -c "${BLENDER_BIN_URL}" -O "${T}/blender_daily.tar.xz" || die "failed to fetch ${BLENDER_BIN_URL}"
			my_A="${T}/blender_daily.tar.xz"
		else
			wget "https://builder.blender.org/download/daily/?format=json&v=1" -O "${T}/release.json" \
				|| die "failed to retrieve release.json"

			local branch commit file_name file_size rel_json release_cycle url version
			rel_json=$(
				jq -r 'map(select(.platform == "linux" and .branch == "main" and .file_extension == "xz")) | .[0]' \
					"${T}/release.json"
			)
			branch=$( echo "${rel_json}" | jq -r '.branch' )
			commit=$( echo "${rel_json}" | jq -r '.hash' )
			file_name=$( echo "${rel_json}" | jq -r '.file_name' )
			file_size=$( echo "${rel_json}" | jq -r '.file_size' )
			release_cycle=$( echo "${rel_json}" | jq -r '.release_cycle' )
			url=$( echo "${rel_json}" | jq -r '.url' )
			version=$( echo "${rel_json}" | jq -r '.version' )

			einfo "Fetching blender-${version}-${release_cycle}-${branch}-${commit}"
			einfo "            url: ${url}"
			einfo "        version: ${version}"
			einfo "  release_cycle: ${release_cycle}"
			einfo "         branch: ${branch}"
			einfo "         commit: ${commit}"
			einfo

			wget -c "${url}" "${url}.sha256" -P "${T}" || die "failed to fetch ${url}"

			# Check file size
			local file_size_is
			file_size_is=$(stat --printf="%s" "${T}/${file_name}")
			if [[ ${file_size_is} -ne "${file_size}" ]]; then
				eerror "size_mismatch mismatch for ${file_name}"
				eerror "  expected ${file_size}"
				eerror "  found    ${file_size_is}"
				die "size_mismatch mismatch"
			fi

			# Check sha256sum
			local sha256sum_exp sha256sum_is
			sha256sum_exp="$(cat "${T}/${file_name}.sha256")"
			sha256sum_is="$(sha256sum "${T}/${file_name}" | cut -d ' ' -f 1)"
			if [[ "${sha256sum_exp}" != "${sha256sum_is}" ]]; then
				eerror "sha256sum mismatch for ${file_name}"
				eerror "  expected ${sha256sum_exp}"
				eerror "  found    ${sha256sum_is}"
				die "sha256sum mismatch"
			fi
			my_A="${T}/${file_name}"
		fi
	else
		my_A="${DISTDIR}/blender-${PV}-linux-x64.tar.xz"
	fi

	mkdir -p "${S}" || die "failed to create ${S}"

	tar xJf "${my_A}" --directory "${S}" --strip-components=1 || die "failed to unpack ${my_A}"
}

src_prepare() {
	default

	if ! use oneapi; then
		rm \
			lib/libpi_level_zero* \
			|| die "failed cleaning oneapi"
	fi

	# Prepare icons and .desktop for menu entry
	mv blender.desktop "${P}.desktop" || die
	mv blender.svg "${P}.svg" || die
	mv blender-symbolic.svg "${P}-symbolic.svg" || die

	# X-KDE-RunOnDiscreteGpu is obsolete, so trim it
	sed \
		-e "s/=blender/=${P}/" \
		-e "s/Name=Blender/Name=Blender Bin ${PV}/" \
		-e "/X-KDE-RunOnDiscreteGpu.*/d" \
		-i "${P}.desktop" || die
}

src_configure() {
	:;
}

src_compile() {
	:;
}

src_install() {
	# We could use the version from the release.json instead of PN here
	local BLENDER_OPT_HOME="/opt/${P}"

	# Install icons and .desktop for menu entry
	doicon -s scalable "${S}"/blender*.svg
	domenu "${P}.desktop"

	# Install all the blender files in /opt
	dodir "${BLENDER_OPT_HOME%/*}"
	mv "${S}" "${ED}${BLENDER_OPT_HOME}" || die

	# Create symlink /usr/bin/blender-bin
	dodir "/usr/bin"
	dosym -r "${BLENDER_OPT_HOME}/blender" "/usr/bin/${P}"
}

pkg_postinst() {
	xdg_icon_cache_update
	xdg_mimeinfo_database_update
	xdg_desktop_database_update
}

pkg_postrm() {
	xdg_icon_cache_update
	xdg_mimeinfo_database_update
	xdg_desktop_database_update
}
