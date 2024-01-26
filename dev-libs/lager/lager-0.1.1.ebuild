# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

DESCRIPTION="Library to assist value-oriented design"
HOMEPAGE="https://sinusoid.es/lager/"
SRC_URI="https://github.com/arximboldi/${PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="MIT"
KEYWORDS="~amd64 ~arm ~arm64 ~ppc64 ~riscv ~x86"
IUSE=""
#RESTRICT="!test? ( test )"
SLOT=0

RDEPEND="
dev-libs/boost
dev-libs/zug
dev-libs/immer
"
DEPEND="${RDEPEND}"
BDEPEND="
"

src_configure() {

	local mycmakeargs=(
		-Dlager_BUILD_DEBUGGER_EXAMPLES=OFF
		-Dlager_BUILD_DOCS=OFF
		-Dlager_BUILD_EXAMPLES=OFF
		-Dlager_BUILD_FAILURE_TESTS=OFF
		-Dlager_BUILD_TESTS=OFF
	)

	cmake_src_configure
}
