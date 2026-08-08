// nanosvg implementation for the test executables: libslic3r (NSVGUtils, Format/svg)
// references the nanosvg C API, whose implementation is otherwise only compiled into the
// GUI library (see src/slic3r/GUI/BitmapCache.cpp).
#define NANOSVG_IMPLEMENTATION
#define NANOSVGRAST_IMPLEMENTATION
#include "nanosvg/nanosvg.h"
#include "nanosvg/nanosvgrast.h"
