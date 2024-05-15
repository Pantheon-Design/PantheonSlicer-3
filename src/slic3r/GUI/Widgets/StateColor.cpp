#include "StateColor.hpp"
#include <cmath>

static bool gDarkMode = false;

static bool operator<(wxColour const &l, wxColour const &r) { return l.GetRGBA() < r.GetRGBA(); }

static std::map<wxColour, wxColour> gDarkColors{
    {"#94D1B0", "#00675b"},
    {"#1F8EEA", "#2778D2"},
    {"#FF6F00", "#D15B00"},
    {"#D01B1B", "#BB2A3A"},
    {"#262E30", "#EFEFF0"},
    {"#2C2C2E", "#B3B3B4"},
    {"#6B6B6B", "#818183"},
    {"#ACACAC", "#54545A"},
    {"#EEEEEE", "#4C4C55"},
    {"#E8E8E8", "#3E3E45"},
    {"#323A3D", "#E5E5E4"},
    {"#FFFFFF", "#2D2D31"},
    {"#F8F8F8", "#36363C"},
    {"#F1F1F1", "#36363B"},
    {"#3B4446", "#2D2D30"},
    {"#CECECE", "#54545B"},
    {"#DBFDD5", "#3B3B40"},
    {"#000000", "#FFFFFE"},
    {"#F4F4F4", "#36363D"},
    {"#DBDBDB", "#4A4A51"},
    {"#EDFAF2", "#283232"},
    {"#323A3C", "#E5E5E6"},
    {"#6B6B6A", "#B3B3B5"},
    {"#303A3C", "#E5E5E5"},
    {"#FEFFFF", "#242428"},
    {"#A6A9AA", "#2D2D29"},
    {"#363636", "#B2B3B5"},
    {"#F0F0F1", "#404040"},
    {"#9E9E9E", "#53545A"},
    {"#D7E8DE", "#1F2B27"},
    {"#2B3436", "#808080"},
    {"#ABABAB", "#ABABAB"},
    {"#D9D9D9", "#2D2D32"},
    //{"#F0F0F0", "#4C4C54"},
	// ORCA
    {"#B5FFD6", "#223C3C"}, // rgb(191, 225, 222)	Dropdown checked item background color > ORCA color with %25 opacity
    {"#E5F0EE", "#283232"}, // rgb(229, 240, 238)	Combo / Dropdown focused background color > ORCA color with %10 opacity
};

std::tuple<double, double, double> StateColor::GetLAB(const wxColour& color) {
    // Convert color to RGB color space
    double r = color.Red() / 255.0;
    double g = color.Green() / 255.0;
    double b = color.Blue() / 255.0;

    // Convert to XYZ color space
    double x = 0.412453*r + 0.357580*g + 0.180423*b;
    double y = 0.212671*r + 0.715160*g + 0.072169*b;
    double z = 0.019334*r + 0.119193*g + 0.950227*b;

    // Normalize XYZ values
    double x_n = x / 0.950456;
    double y_n = y / 1.0;
    double z_n = z / 1.088754;

    // Convert to LAB color space
    double epsilon = 0.008856;
    double kappa = 903.3;
    double fx = (x_n > epsilon) ? cbrt(x_n) : (kappa*x_n + 16.0) / 116.0;
    double fy = (y_n > epsilon) ? cbrt(y_n) : (kappa*y_n + 16.0) / 116.0;
    double fz = (z_n > epsilon) ? cbrt(z_n) : (kappa*z_n + 16.0) / 116.0;

    double l = 116.0 * fy - 16.0;
    double a = 500.0 * (fx - fy);
    double b_lab = 200.0 * (fy - fz);

    return std::tuple<double, double, double>(l, a, b_lab);
}

double StateColor::LAB_Delta_E(const wxColour& color1, const wxColour& color2) {
    auto [l1, a1, b1] = GetLAB(color1);
    auto [l2, a2, b2] = GetLAB(color2);
    return sqrt((l1 - l2) * (l1 - l2) + (a1 - a2) * (a1 - a2) + (b1 - b2) * (b1 - b2));
}

double StateColor::GetColorDifference(const wxColour& color1, const wxColour& color2) {
    return LAB_Delta_E(color1, color2);
}

double StateColor::GetLightness(const wxColour& color) {
    auto [l, a, b_lab] = GetLAB(color);
    return l;
}

// Function to lighten or darken a wxColour using LAB color space
wxColour StateColor::SetLightness(const wxColour& color, double lightness) {
    auto [l, a, b_lab] = GetLAB(color);

    // Clamp lightness value
    l = std::max(0.0, std::min(100.0, lightness));

    // Convert back to XYZ color space
    double fy_3 = (l + 16.0) / 116.0;
    double fx_3 = a / 500.0 + fy_3;
    double fz_3 = fy_3 - b_lab / 200.0;

    double epsilon = 0.008856;
    double kappa = 903.3;
    double x_3 = (fx_3 > epsilon) ? fx_3 * fx_3 * fx_3 : (116.0 * fx_3 - 16.0) / kappa;
    double y_3 = (l > kappa*epsilon) ? fy_3 * fy_3 * fy_3 : l / kappa;
    double z_3 = (fz_3 > epsilon) ? fz_3 * fz_3 * fz_3 : (116.0 * fz_3 - 16.0) / kappa;

    // Denormalize XYZ values
    double x = x_3 * 0.950456;
    double y = y_3 * 1.0;
    double z = z_3 * 1.088754;

    // Convert XYZ to RGB
    double r_new = 3.240479*x - 1.537150*y - 0.498535*z;
    double g_new = -0.969256*x + 1.875992*y + 0.041556*z;
    double b_new = 0.055648*x - 0.204043*y + 1.057311*z;

    // Clamp RGB values
    r_new = std::max(0.0, std::min(1.0, r_new));
    g_new = std::max(0.0, std::min(1.0, g_new));
    b_new = std::max(0.0, std::min(1.0, b_new));

    // Convert back to wxColour
    int r_int = static_cast<int>(r_new * 255);
    int g_int = static_cast<int>(g_new * 255);
    int b_int = static_cast<int>(b_new * 255);

    return wxColour(r_int, g_int, b_int);
}

wxColour StateColor::LightenDarkenColor(const wxColour& color, int amount) {
    auto [l, a, b_lab] = GetLAB(color);

    // Modify lightness
    l += amount;

    // Clamp lightness value
    l = std::max(0.0, std::min(100.0, l));

    // Convert back to XYZ color space
    double fy_3 = (l + 16.0) / 116.0;
    double fx_3 = a / 500.0 + fy_3;
    double fz_3 = fy_3 - b_lab / 200.0;

    double epsilon = 0.008856;
    double kappa = 903.3;
    double x_3 = (fx_3 > epsilon) ? fx_3 * fx_3 * fx_3 : (116.0 * fx_3 - 16.0) / kappa;
    double y_3 = (l > kappa*epsilon) ? fy_3 * fy_3 * fy_3 : l / kappa;
    double z_3 = (fz_3 > epsilon) ? fz_3 * fz_3 * fz_3 : (116.0 * fz_3 - 16.0) / kappa;

    // Denormalize XYZ values
    double x = x_3 * 0.950456;
    double y = y_3 * 1.0;
    double z = z_3 * 1.088754;

    // Convert XYZ to RGB
    double r_new = 3.240479*x - 1.537150*y - 0.498535*z;
    double g_new = -0.969256*x + 1.875992*y + 0.041556*z;
    double b_new = 0.055648*x - 0.204043*y + 1.057311*z;

    // Clamp RGB values
    r_new = std::max(0.0, std::min(1.0, r_new));
    g_new = std::max(0.0, std::min(1.0, g_new));
    b_new = std::max(0.0, std::min(1.0, b_new));

    // Convert back to wxColour
    int r_int = static_cast<int>(r_new * 255);
    int g_int = static_cast<int>(g_new * 255);
    int b_int = static_cast<int>(b_new * 255);

    return wxColour(r_int, g_int, b_int);
}

std::map<wxColour, wxColour> const & StateColor::GetDarkMap()
{
    return gDarkColors;
}

void StateColor::SetDarkMode(bool dark) { gDarkMode = dark; }

inline wxColour darkModeColorFor2(wxColour const &color)
{
    if (!gDarkMode)
        return color;
    auto iter = gDarkColors.find(color);
    wxASSERT(iter != gDarkColors.end());
    if (iter != gDarkColors.end()) return iter->second;
    return color;
}

std::map<wxColour, wxColour> revert(std::map<wxColour, wxColour> const & map)
{
    std::map<wxColour, wxColour> map2;
    for (auto &p : map) map2.emplace(p.second, p.first);
    return map2;
}

wxColour StateColor::lightModeColorFor(wxColour const &color)
{
    static std::map<wxColour, wxColour> gLightColors = revert(gDarkColors);
    auto iter = gLightColors.find(color);
    wxASSERT(iter != gLightColors.end());
    if (iter != gLightColors.end()) return iter->second;
    return color;
}

wxColour StateColor::darkModeColorFor(wxColour const &color) { return darkModeColorFor2(color); }

StateColor::StateColor(wxColour const &color) { append(color, 0); }

StateColor::StateColor(wxString const &color) { append(color, 0); }

StateColor::StateColor(unsigned long color) { append(color, 0); }

void StateColor::append(wxColour const & color, int states)
{
    statesList_.push_back(states);
    colors_.push_back(color);
}

void StateColor::append(wxString const & color, int states)
{
    wxColour c1(color);
    append(c1, states);
}

void StateColor::append(unsigned long color, int states)
{
    if ((color & 0xff000000) == 0)
        color |= 0xff000000;
    wxColour cl; cl.SetRGBA(color & 0xff00ff00 | ((color & 0xff) << 16) | ((color >> 16) & 0xff));
    append(cl, states);
}

void StateColor::clear()
{
    statesList_.clear();
    colors_.clear();
}

int StateColor::states() const
{
    int states = 0;
    for (auto s : statesList_) states |= s;
    states = (states & 0xffff) | (states >> 16);
    if (takeFocusedAsHovered_ && (states & Hovered))
        states |= Focused;
    return states;
}

wxColour StateColor::defaultColor() {
    return colorForStates(0);
}

wxColour StateColor::colorForStates(int states)
{
    bool focused = takeFocusedAsHovered_ && (states & Focused);
    for (int i = 0; i < statesList_.size(); ++i) {
        int s = statesList_[i];
        int on = s & 0xffff;
        int off = s >> 16;
        if ((on & states) == on && (off & ~states) == off) {
            return darkModeColorFor2(colors_[i]);
        }
        if (focused && (on & Hovered)) {
            on |= Focused;
            on &= ~Hovered;
            if ((on & states) == on && (off & ~states) == off) {
                return darkModeColorFor2(colors_[i]);
            }
        }
    }
    return wxColour(0, 0, 0, 0);
}

wxColour StateColor::colorForStatesNoDark(int states)
{
    bool focused = takeFocusedAsHovered_ && (states & Focused);
    for (int i = 0; i < statesList_.size(); ++i) {
        int s = statesList_[i];
        int on = s & 0xffff;
        int off = s >> 16;
        if ((on & states) == on && (off & ~states) == off) {
            return colors_[i];
        }
        if (focused && (on & Hovered)) {
            on |= Focused;
            on &= ~Hovered;
            if ((on & states) == on && (off & ~states) == off) {
                return colors_[i];
            }
        }
    }
    return wxColour(0, 0, 0, 0);
}

int StateColor::colorIndexForStates(int states)
{
    for (int i = 0; i < statesList_.size(); ++i) {
        int s   = statesList_[i];
        int on  = s & 0xffff;
        int off = s >> 16;
        if ((on & states) == on && (off & ~states) == off) { return i; }
    }
    return -1;
}

bool StateColor::setColorForStates(wxColour const &color, int states)
{
    for (int i = 0; i < statesList_.size(); ++i) {
        if (statesList_[i] == states) {
            colors_[i] = color;
            return true;
        }
    }
    return false;
}

void StateColor::setTakeFocusedAsHovered(bool set) { takeFocusedAsHovered_ = set; }
