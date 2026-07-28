#ifndef slic3r_SliceProfileStats_hpp_
#define slic3r_SliceProfileStats_hpp_

#include <atomic>
#include <chrono>
#include <cstdint>

namespace Slic3r {

// Per-slice wall-time accumulators for profiling the slicing + g-code export pipeline.
// All fields are microseconds. Atomic so TBB parallel_for workers can update them safely.
struct SliceProfileStats
{
    // Per-PrintObject phases (summed across all objects).
    std::atomic<int64_t> us_make_perimeters_total      {0};
    std::atomic<int64_t> us_make_perimeters_parallel   {0};
    std::atomic<int64_t> us_prepare_infill_total       {0};
    std::atomic<int64_t> us_infill_total               {0};
    std::atomic<int64_t> us_infill_parallel            {0};
    std::atomic<int64_t> us_ironing_total              {0};
    std::atomic<int64_t> us_generate_support_material  {0};
    std::atomic<int64_t> us_simplify_walls             {0};
    std::atomic<int64_t> us_simplify_infill            {0};
    std::atomic<int64_t> us_simplify_support           {0};

    // Print-level phases.
    std::atomic<int64_t> us_print_process_total        {0};
    std::atomic<int64_t> us_tool_ordering              {0};
    std::atomic<int64_t> us_wipe_tower                 {0};
    std::atomic<int64_t> us_skirt_brim                 {0};

    // G-code export.
    std::atomic<int64_t> us_gcode_do_export_total      {0};
    std::atomic<int64_t> us_gcode_setup_pre_pipeline   {0};
    std::atomic<int64_t> us_seam_placer_init           {0};
    std::atomic<int64_t> us_process_layers_total       {0};

    // Pipeline filters — cumulative across all layers.
    std::atomic<int64_t> us_process_layer_cumulative   {0};
    std::atomic<int64_t> us_filter_spiral_vase         {0};
    std::atomic<int64_t> us_filter_pressure_equalizer  {0};
    std::atomic<int64_t> us_filter_cooling             {0};
    std::atomic<int64_t> us_filter_fan_mover           {0};
    std::atomic<int64_t> us_filter_pa_processor        {0};
    std::atomic<int64_t> us_filter_output_write        {0};

    // process_layer internals — cumulative across all layer invocations.
    std::atomic<int64_t> us_inlayer_change_layer       {0};
    std::atomic<int64_t> us_inlayer_seam_placement     {0};
    std::atomic<int64_t> us_inlayer_acp_init_layer     {0};
    std::atomic<int64_t> us_inlayer_extrude_perimeters {0};
    std::atomic<int64_t> us_inlayer_extrude_infill     {0};
    std::atomic<int64_t> us_inlayer_extrude_loop       {0};
    std::atomic<int64_t> us_inlayer_extrude_path       {0};
    std::atomic<int64_t> us_inlayer_placeholder_parser {0};

    // Coarse counters.
    std::atomic<int64_t> count_layers_processed        {0};
    std::atomic<int64_t> count_seam_placements         {0};
    std::atomic<int64_t> count_extrude_loop_calls      {0};

    void reset() {
        us_make_perimeters_total     .store(0, std::memory_order_relaxed);
        us_make_perimeters_parallel  .store(0, std::memory_order_relaxed);
        us_prepare_infill_total      .store(0, std::memory_order_relaxed);
        us_infill_total              .store(0, std::memory_order_relaxed);
        us_infill_parallel           .store(0, std::memory_order_relaxed);
        us_ironing_total             .store(0, std::memory_order_relaxed);
        us_generate_support_material .store(0, std::memory_order_relaxed);
        us_simplify_walls            .store(0, std::memory_order_relaxed);
        us_simplify_infill           .store(0, std::memory_order_relaxed);
        us_simplify_support          .store(0, std::memory_order_relaxed);

        us_print_process_total       .store(0, std::memory_order_relaxed);
        us_tool_ordering             .store(0, std::memory_order_relaxed);
        us_wipe_tower                .store(0, std::memory_order_relaxed);
        us_skirt_brim                .store(0, std::memory_order_relaxed);

        us_gcode_do_export_total     .store(0, std::memory_order_relaxed);
        us_gcode_setup_pre_pipeline  .store(0, std::memory_order_relaxed);
        us_seam_placer_init          .store(0, std::memory_order_relaxed);
        us_process_layers_total      .store(0, std::memory_order_relaxed);

        us_process_layer_cumulative  .store(0, std::memory_order_relaxed);
        us_filter_spiral_vase        .store(0, std::memory_order_relaxed);
        us_filter_pressure_equalizer .store(0, std::memory_order_relaxed);
        us_filter_cooling            .store(0, std::memory_order_relaxed);
        us_filter_fan_mover          .store(0, std::memory_order_relaxed);
        us_filter_pa_processor       .store(0, std::memory_order_relaxed);
        us_filter_output_write       .store(0, std::memory_order_relaxed);

        us_inlayer_change_layer      .store(0, std::memory_order_relaxed);
        us_inlayer_seam_placement    .store(0, std::memory_order_relaxed);
        us_inlayer_acp_init_layer    .store(0, std::memory_order_relaxed);
        us_inlayer_extrude_perimeters.store(0, std::memory_order_relaxed);
        us_inlayer_extrude_infill    .store(0, std::memory_order_relaxed);
        us_inlayer_extrude_loop      .store(0, std::memory_order_relaxed);
        us_inlayer_extrude_path      .store(0, std::memory_order_relaxed);
        us_inlayer_placeholder_parser.store(0, std::memory_order_relaxed);

        count_layers_processed       .store(0, std::memory_order_relaxed);
        count_seam_placements        .store(0, std::memory_order_relaxed);
        count_extrude_loop_calls     .store(0, std::memory_order_relaxed);
    }
};

class ScopedProfileTimer
{
public:
    explicit ScopedProfileTimer(std::atomic<int64_t>& accumulator)
        : m_acc(accumulator), m_t0(std::chrono::steady_clock::now()) {}
    ~ScopedProfileTimer() {
        const auto us = std::chrono::duration_cast<std::chrono::microseconds>(
            std::chrono::steady_clock::now() - m_t0).count();
        m_acc.fetch_add(us, std::memory_order_relaxed);
    }
    ScopedProfileTimer(const ScopedProfileTimer&) = delete;
    ScopedProfileTimer& operator=(const ScopedProfileTimer&) = delete;

private:
    std::atomic<int64_t>& m_acc;
    std::chrono::steady_clock::time_point m_t0;
};

#define ORCA_PROFILE_CONCAT_INNER(a, b) a##b
#define ORCA_PROFILE_CONCAT(a, b) ORCA_PROFILE_CONCAT_INNER(a, b)
#define ORCA_PROFILE_SCOPE(field) \
    ::Slic3r::ScopedProfileTimer ORCA_PROFILE_CONCAT(_orca_prof_, __LINE__)(field)

} // namespace Slic3r

#endif // slic3r_SliceProfileStats_hpp_
