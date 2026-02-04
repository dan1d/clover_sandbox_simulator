# frozen_string_literal: true

module CloverSandboxSimulator
  module Services
    module Clover
      # Manages Clover employee shifts (clock in/out, shift tracking)
      class ShiftService < BaseService
        # Fetch all shifts
        def get_shifts(limit: 100)
          logger.info "Fetching shifts..."
          response = request(:get, endpoint("shifts"), params: { limit: limit })
          shifts = response&.dig("elements") || []
          logger.info "Found #{shifts.size} shifts"
          shifts
        end

        # Clock in an employee (start a shift)
        # @param employee_id [String] The employee ID
        # @param in_time [Integer, nil] The clock-in time in milliseconds (defaults to now)
        def clock_in(employee_id:, in_time: nil)
          in_time ||= (Time.now.to_f * 1000).to_i

          logger.info "Clocking in employee #{employee_id}"

          payload = {
            "employee" => { "id" => employee_id },
            "inTime" => in_time
          }

          request(:post, endpoint("shifts"), payload: payload)
        end

        # Clock out an employee (end a shift)
        # @param shift_id [String] The shift ID
        # @param out_time [Integer, nil] The clock-out time in milliseconds (defaults to now)
        def clock_out(shift_id:, out_time: nil)
          out_time ||= (Time.now.to_f * 1000).to_i

          logger.info "Clocking out shift #{shift_id}"

          payload = { "outTime" => out_time }

          request(:post, endpoint("shifts/#{shift_id}"), payload: payload)
        end

        # Get all active shifts (shifts without an outTime)
        def get_active_shifts
          shifts = get_shifts
          shifts.select { |s| s["outTime"].nil? }
        end

        # Get the active shift for a specific employee
        # @param employee_id [String] The employee ID
        # @return [Hash, nil] The active shift or nil
        def get_employee_shift(employee_id:)
          active = get_active_shifts
          active.find { |s| s.dig("employee", "id") == employee_id }
        end

        # Clock out all active shifts (end of day cleanup)
        def clock_out_all_active(out_time: nil)
          active = get_active_shifts
          return [] if active.empty?

          logger.info "Clocking out #{active.size} active shifts"

          active.map do |shift|
            clock_out(shift_id: shift["id"], out_time: out_time)
          rescue StandardError => e
            logger.warn "Failed to clock out shift #{shift['id']}: #{e.message}"
            nil
          end.compact
        end

        # Calculate shift duration in hours
        # @param shift [Hash] A shift object with inTime and outTime
        # @return [Float] Duration in hours
        def calculate_duration(shift)
          in_time = shift["inTime"]
          out_time = shift["outTime"]

          return 0 if in_time.nil? || out_time.nil?

          # Times are in milliseconds
          duration_ms = out_time - in_time
          duration_ms / (1000.0 * 60 * 60) # Convert to hours
        end
      end
    end
  end
end
