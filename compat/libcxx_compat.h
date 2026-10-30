// Force-included into every C++ file of the macOS build.
// Lets the code build against older Apple C++ libraries (Xcode 14 / libc++ 15) so the result runs on macOS 13+.
#pragma once
#include <codecvt>
#include <locale>
#include <version>

#if __cplusplus >= 202002L && defined(_LIBCPP_VERSION) && _LIBCPP_VERSION < 16000
#include <ranges>
// std::views::keys/values (elements_view) arrived in libc++ 16.
namespace std::ranges::views
{
inline constexpr auto keys = std::views::transform([]<class Pair>(Pair&& pair) -> decltype(auto) { return (std::forward<Pair>(pair).first); });
inline constexpr auto values = std::views::transform([]<class Pair>(Pair&& pair) -> decltype(auto) { return (std::forward<Pair>(pair).second); });
} // namespace std::ranges::views
#endif
