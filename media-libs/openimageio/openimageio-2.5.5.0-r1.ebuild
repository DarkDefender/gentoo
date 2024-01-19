# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{10..12} )

TEST_OIIO_IMAGE_COMMIT="aae37a54e31c0e719edcec852994d052ecf6541e"
TEST_OEXR_IMAGE_COMMIT="df16e765fee28a947244657cae3251959ae63c00"
inherit cmake flag-o-matic font python-single-r1

DESCRIPTION="A library for reading and writing images"
HOMEPAGE="https://sites.google.com/site/openimageio/ https://github.com/OpenImageIO"
SRC_URI="
	https://github.com/AcademySoftwareFoundation/OpenImageIO/archive/v${PV}.tar.gz -> ${P}.tar.gz
	test? (
		https://github.com/AcademySoftwareFoundation/OpenImageIO-images/archive/${TEST_OIIO_IMAGE_COMMIT}.tar.gz -> ${PN}-oiio-test-image-${TEST_OIIO_IMAGE_COMMIT}.tar.gz
		https://github.com/AcademySoftwareFoundation/openexr-images/archive/${TEST_OEXR_IMAGE_COMMIT}.tar.gz -> ${PN}-oexr-test-image-${TEST_OEXR_IMAGE_COMMIT}.tar.gz
	)
"
S="${WORKDIR}/OpenImageIO-${PV}"

LICENSE="BSD"
SLOT="0/$(ver_cut 1-2)"
KEYWORDS="~amd64 ~arm ~arm64 ~ppc64 ~riscv"

X86_CPU_FEATURES=(
	aes:aes sse2:sse2 sse3:sse3 ssse3:ssse3 sse4_1:sse4.1 sse4_2:sse4.2
	avx:avx avx2:avx2 avx512f:avx512f f16c:f16c
)
CPU_FEATURES=( "${X86_CPU_FEATURES[@]/#/cpu_flags_x86_}" )

IUSE="dicom doc ffmpeg gif gui jpeg2k opencv openvdb ptex python qt6 raw test +tools +truetype ${CPU_FEATURES[*]%:*}"
REQUIRED_USE="python? ( ${PYTHON_REQUIRED_USE} ) gui? ( tools )"

# Not quite working yet
RESTRICT="!test? ( test )" # test"

BDEPEND="
	doc? (
		app-text/doxygen
		dev-texlive/texlive-bibtexextra
		dev-texlive/texlive-fontsextra
		dev-texlive/texlive-fontutils
		dev-texlive/texlive-latex
		dev-texlive/texlive-latexextra
	)
"
RDEPEND="
	dev-libs/boost:=
	dev-cpp/robin-map
	dev-libs/libfmt:=
	dev-libs/pugixml:=
	>=media-libs/libheif-1.13.0:=
	media-libs/libjpeg-turbo:=
	media-libs/libpng:0=
	>=media-libs/libwebp-0.2.1:=
	>=dev-libs/imath-3.1.2-r4:=
	>=media-libs/opencolorio-2.1.1-r4:=
	>=media-libs/openexr-3:0=
	media-libs/tiff:=
	sys-libs/zlib:=
	dicom? ( sci-libs/dcmtk )
	ffmpeg? ( media-video/ffmpeg:= )
	gif? ( media-libs/giflib:0= )
	jpeg2k? ( >=media-libs/openjpeg-2.0:2= )
	opencv? ( media-libs/opencv:= )
	openvdb? (
		dev-cpp/tbb:=
		media-gfx/openvdb:=
	)
	ptex? ( media-libs/ptex:= )
	python? (
		${PYTHON_DEPS}
		$(python_gen_cond_dep '
			dev-libs/boost:=[python,${PYTHON_USEDEP}]
			dev-python/numpy[${PYTHON_USEDEP}]
			dev-python/pybind11[${PYTHON_USEDEP}]
		')
	)
	gui? (
		media-libs/libglvnd
		!qt6? (
			dev-qt/qtcore:5
			dev-qt/qtgui:5
			dev-qt/qtopengl:5
			dev-qt/qtwidgets:5
		)
		qt6? (
			dev-qt/qtbase:6[gui,widgets,opengl]
		)
	)
	raw? ( media-libs/libraw:= )
	truetype? ( media-libs/freetype:2= )
"
DEPEND="
	${RDEPEND}
"

DOCS=(
	CHANGES.md
	CREDITS.md
	README.md
)

PATCHES="
	"${FILESDIR}/fix_simd_test.patch"
	"${FILESDIR}/fix_avx512_round.patch"
"

pkg_setup() {
	use python && python-single-r1_pkg_setup
}

src_prepare() {
	use dicom || rm -r "${S}/src/dicom.imageio/" || die
	cmake_src_prepare
	cmake_comment_add_subdirectory src/fonts

	if use test ; then
		mkdir -p "${BUILD_DIR}"/testsuite || die
		mv "${WORKDIR}/OpenImageIO-images-${TEST_OIIO_IMAGE_COMMIT}" "${BUILD_DIR}"/testsuite/oiio-images || die
		mv "${WORKDIR}/openexr-images-${TEST_OEXR_IMAGE_COMMIT}" "${BUILD_DIR}"/testsuite/openexr-images || die
	fi
}

src_configure() {
	# Build with SIMD support
	local cpufeature
	local mysimd=()
	for cpufeature in "${CPU_FEATURES[@]}"; do
		use "${cpufeature%:*}" && mysimd+=("${cpufeature#*:}")
	done

	# If no CPU SIMDs were used, completely disable them
	[[ -z ${mysimd[*]} ]] && mysimd=("0")

	# This is currently needed on arm64 to get the NEON SIMD wrapper to compile the code successfully
	# Even if there are no SIMD features selected, it seems like the code will turn on NEON support if it is available.
	use arm64 && append-flags -flax-vector-conversions

	# When building with more aggressive optimization flags, GCC will add FMA
    # (Fused Multiply Add) instructions that will slightly alter the floating
    # point operation results. This leads to test faliures.
	append-flags -ffp-contract=off

	local mycmakeargs=(
		-DCMAKE_CXX_STANDARD="17"
		-DDOWNSTREAM_CXX_STANDARD="17"
		"-DVERBOSE=ON"
		"-DOIIO_BUILD_TOOLS=$(usex tools)"
		"-DBUILD_TESTING=$(usex test)"
		"-DOIIO_BUILD_TESTS=$(usex test)"
		"-DOIIO_DOWNLOAD_MISSING_TESTDATA=OFF"
		"-DINSTALL_FONTS=OFF"
		"-DBUILD_DOCS=$(usex doc)"
		"-DINSTALL_DOCS=$(usex doc)"
		"-DSTOP_ON_WARNING=OFF"
		"-DUSE_CCACHE=OFF"
		"-DUSE_DCMTK=$(usex dicom)"
		"-DUSE_EXTERNAL_PUGIXML=ON"
		"-DUSE_NUKE=OFF" # not in Gentoo
		"-DUSE_FFMPEG=$(usex ffmpeg)"
		"-DUSE_GIF=$(usex gif)"
		"-DUSE_OPENJPEG=$(usex jpeg2k)"
		"-DUSE_OPENCV=$(usex opencv)"
		"-DUSE_OPENVDB=$(usex openvdb)"
		"-DUSE_PTEX=$(usex ptex)"
		"-DUSE_PYTHON=$(usex python)"
		"-DUSE_LIBRAW=$(usex raw)"
		"-DUSE_FREETYPE=$(usex truetype)"
		"-DUSE_SIMD=$(local IFS=','; echo "${mysimd[*]}")"
	)

	if use gui; then
		mycmakeargs+=( -DENABLE_IV=ON -DUSE_OPENGL=ON -DUSE_QT=ON )
		if ! use qt6; then
			mycmakeargs+=( -DCMAKE_DISABLE_FIND_PACKAGE_Qt6=ON )
		fi
	else
		mycmakeargs+=( -DENABLE_IV=OFF -DUSE_QT=OFF )
	fi

	if use python; then
		mycmakeargs+=(
			"-DPYTHON_VERSION=${EPYTHON#python}"
			"-DPYTHON_SITE_DIR=$(python_get_sitedir)"
		)
	fi

	cmake_src_configure
}

src_test() {
	tests_to_skip=()
	if ! use jpeg2k ; then
		tests_to_skip+=( jpeg2000-broken )
	fi

	if ! use openvdb ; then
		tests_to_skip+=( openvdb-broken openvdb.batch-broken texture-texture3d-broken texture-texture3d.batch-broken )
	fi

	if ! use ptex ; then
		tests_to_skip+=( ptex-broken )
	fi

	if ! use raw ; then
		tests_to_skip+=( raw-broken )
	fi

	if [[ ! -z ${tests_to_skip[*]} ]]; then
		# Create a proper regexp that only matches the tests exactly
		test_skip_regexp=$(printf "|^%s$" "${tests_to_skip[@]}")
		test_skip_regexp="(${test_skip_regexp:1})"
		local myctestargs=( -E $test_skip_regexp )
	fi

	cmake_src_test
}

src_install() {
	cmake_src_install
	# can't use font_src_install
	# it does directory hierarchy recreation
	FONT_S=(
		"${S}/src/fonts/Droid_Sans"
		"${S}/src/fonts/Droid_Sans_Mono"
		"${S}/src/fonts/Droid_Serif"
	)
	insinto "${FONTDIR}"
	for dir in "${FONT_S[@]}"; do
		doins "${dir}"/*.ttf
	done
}
