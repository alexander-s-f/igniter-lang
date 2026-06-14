#!/usr/bin/env ruby
# frozen_string_literal: true
#
# verify_stdlib_math_p1.rb
# Verification survey runner for LANG-STDLIB-MATH-P1.
# Targets at least 45 checks to ground the proposal in evidence.
#

require "json"
require "pathname"

LANG_ROOT = Pathname.new(__dir__).parent.parent
LAB_ROOT = LANG_ROOT.parent / "igniter-lab"

APP_DIR = LAB_ROOT / "igniter-apps" / "air_combat"
VEC_IG = APP_DIR / "vec.ig"
GUIDANCE_IG = APP_DIR / "guidance.ig"
REGISTRY_MD = APP_DIR / "PRESSURE_REGISTRY.md"
INVENTORY_JSON = LANG_ROOT / "docs/spec/stdlib-inventory.json"
PROPOSAL_MD = LANG_ROOT / ".agents/work/proposals/LANG-STDLIB-MATH-P1-readiness-v0.md"
CARD_MD = LANG_ROOT / ".agents/work/cards/lang/LANG-STDLIB-MATH-P1.md"
PROPOSALS_README = LANG_ROOT / ".agents/work/proposals/README.md"

$pass_count = 0
$fail_count = 0

def check(label)
  result = yield
  if result
    puts "  PASS: #{label}"
    $pass_count += 1
  else
    puts "  FAIL: #{label}"
    $fail_count += 1
  end
rescue => e
  puts "  ERROR: #{label} — #{e.class}: #{e.message.lines.first&.strip}"
  $fail_count += 1
end

# Load helper contents
vec_src = VEC_IG.exist? ? File.read(VEC_IG, encoding: "UTF-8") : ""
guidance_src = GUIDANCE_IG.exist? ? File.read(GUIDANCE_IG, encoding: "UTF-8") : ""
registry_src = REGISTRY_MD.exist? ? File.read(REGISTRY_MD, encoding: "UTF-8") : ""
proposal_src = PROPOSAL_MD.exist? ? File.read(PROPOSAL_MD, encoding: "UTF-8") : ""
card_src = CARD_MD.exist? ? File.read(CARD_MD, encoding: "UTF-8") : ""
proposals_readme_src = PROPOSALS_README.exist? ? File.read(PROPOSALS_README, encoding: "UTF-8") : ""

inventory_hash = nil
if INVENTORY_JSON.exist?
  begin
    inventory_hash = JSON.parse(File.read(INVENTORY_JSON, encoding: "UTF-8"))
  rescue
    inventory_hash = :corrupt
  end
end

puts "\nSection A — Preconditions"
check("A-01: igniter-lang directory exists") { LANG_ROOT.directory? }
check("A-02: igniter-lab directory exists") { LAB_ROOT.directory? }
check("A-03: air_combat app directory exists") { APP_DIR.directory? }
check("A-04: air_combat vec.ig exists") { VEC_IG.file? }
check("A-05: air_combat guidance.ig exists") { GUIDANCE_IG.file? }
check("A-06: air_combat PRESSURE_REGISTRY.md exists") { REGISTRY_MD.file? }
check("A-07: stdlib-inventory.json exists") { INVENTORY_JSON.file? }
check("A-08: proposal document exists") { PROPOSAL_MD.file? }
check("A-09: vector_math app directory exists") { (LAB_ROOT / "igniter-apps" / "vector_math").directory? }
check("A-10: neural_net app directory exists") { (LAB_ROOT / "igniter-apps" / "neural_net").directory? }

puts "\nSection B — air_combat kinematic workarounds"
check("B-01: vec.ig declares VMag2 contract") { vec_src.include?("pure contract VMag2") }
check("B-02: vec.ig declares VDist2 contract") { vec_src.include?("pure contract VDist2") }
check("B-03: vec.ig documents that no sqrt is available") { vec_src.include?("No sqrt is available") }
check("B-04: vec.ig documents squared distances workaround") { vec_src.include?("distances are kept SQUARED") }
check("B-05: guidance.ig documents proportional navigation needs unit vector") { guidance_src.include?("navigation needs a unit vector") }
check("B-06: PRESSURE_REGISTRY.md contains pressure code AC-P07") { registry_src.include?("AC-P07") }
check("B-07: PRESSURE_REGISTRY.md describes missing math pressure") { registry_src.include?("missing math: sqrt / normalize") }

puts "\nSection C — Proposal Document decisions"
check("C-01: proposal source is not empty") { !proposal_src.empty? }
check("C-02: proposal specifies abs(Integer) -> Integer") { proposal_src.include?("abs(x: Integer) -> Integer") }
check("C-03: proposal specifies sqrt(Integer) -> Integer") { proposal_src.include?("sqrt(x: Integer) -> Integer") }
check("C-04: proposal specifies hypot(Integer, Integer) -> Integer") { proposal_src.include?("hypot(x: Integer, y: Integer) -> Integer") }
check("C-05: proposal decides on strictly integer operations (fixed-point at app level)") { proposal_src.include?("Strictly Integer Operations") }
check("C-06: proposal describes floor rounding/truncation (isqrt)") { proposal_src.include?("Floor Truncation") }
check("C-07: proposal describes totality policy returning 0 for negative input") { proposal_src.include?("returns 0 for negative input") }
check("C-08: proposal specifies compile-time negative literal guard") { proposal_src.include?("negative literal is compile-time") }
check("C-09: proposal mentions other apps (vector_math, neural_net)") { proposal_src.include?("vector_math") && proposal_src.include?("neural_net") }
check("C-10: proposal decides on stdlib-only VM semantics (no VM instructions)") { proposal_src.include?("no new VM instructions") }
check("C-11: proposal defines OOF-MTH* namespace") { proposal_src.include?("OOF-MTH*") }
check("C-12: proposal defines diagnostic OOF-MTH1") { proposal_src.include?("OOF-MTH1") }
check("C-13: proposal excludes floats and decimals from math surface") { proposal_src.include?("No float or decimal math support") }
check("C-14: proposal excludes trigonometry") { proposal_src.include?("No trigonometry") }
check("C-15: proposal excludes logs and exponentials") { proposal_src.include?("No logarithmic") }
check("C-16: proposal has JSON schema entry for abs") { proposal_src.include?("stdlib.math.abs") }
check("C-17: proposal has JSON schema entry for sqrt") { proposal_src.include?("stdlib.math.sqrt") }
check("C-18: proposal has JSON schema entry for hypot") { proposal_src.include?("stdlib.math.hypot") }

puts "\nSection D — stdlib-inventory.json current state validation"
check("D-01: stdlib-inventory.json parsed correctly") { inventory_hash.is_a?(Hash) }
check("D-02: inventory contains entries array") { inventory_hash["entries"].is_a?(Array) }
check("D-03: entries array is not empty") { !inventory_hash["entries"].empty? }
check("D-04: no entry has category math") { inventory_hash["entries"].none? { |e| e["category"] == "math" } }
check("D-05: no entry starts with stdlib.math.") { inventory_hash["entries"].none? { |e| e["canonical_name"].to_s.start_with?("stdlib.math.") } }
check("D-06: text category entries exist") { inventory_hash["entries"].any? { |e| e["category"] == "text" } }
check("D-07: collection category entries exist") { inventory_hash["entries"].any? { |e| e["category"] == "collection" } }
check("D-08: entries contains stdlib.text.byte_length") { inventory_hash["entries"].any? { |e| e["canonical_name"] == "stdlib.text.byte_length" } }
check("D-09: entries contains stdlib.text.concat") { inventory_hash["entries"].any? { |e| e["canonical_name"] == "stdlib.text.concat" } }
check("D-10: stdlib_surface_digest key present") { !inventory_hash["stdlib_surface_digest"].nil? }

puts "\nSection E — Card Status & Metadata consistency"
check("E-01: card status is marked CLOSED") { card_src.include?("CLOSED") }
check("E-02: card status matches closure state") { card_src.include?("ROUTED") || card_src.include?("PROPOSED") }
check("E-03: proposals README.md exists") { PROPOSALS_README.file? }
check("E-04: proposals README.md references LANG-STDLIB-MATH-P1") { proposals_readme_src.include?("LANG-STDLIB-MATH-P1") }
check("E-05: proposals README.md summary mentions abs/sqrt/hypot") { proposals_readme_src.include?("abs") && proposals_readme_src.include?("sqrt") && proposals_readme_src.include?("hypot") }

puts "\nSection F — central portfolio-index.md"
check("F-01: central portfolio-index.md exists") { (LAB_ROOT / ".agents" / "portfolio-index.md").file? }
check("F-02: portfolio-index.md contains LANG-STDLIB-MATH-P1") { (LAB_ROOT / ".agents" / "portfolio-index.md").read.include?("LANG-STDLIB-MATH-P1") }

total = $pass_count + $fail_count
puts "\n" + "=" * 60
puts "RESULT: #{$pass_count}/#{total} PASS  |  #{$fail_count} FAIL"
puts "=" * 60
exit($fail_count.zero? ? 0 : 1)
