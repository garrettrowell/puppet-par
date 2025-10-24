# frozen_string_literal: true

# Local RSpec configuration that persists through PDK updates
# This file is loaded by spec_helper.rb but is not managed by PDK

# Load shared contexts from spec/support/
# This enables cross-platform testing helpers like windows_cross_compatibility
Dir[File.join(__dir__, 'support', '**', '*.rb')].sort.each { |f| require f }
