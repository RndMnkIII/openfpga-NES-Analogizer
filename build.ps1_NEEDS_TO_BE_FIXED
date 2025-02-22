if (($args.count -ne 1) -or ($args[0] -eq "")) {
  Write-Output "Expected build type arg"
  exit 1
}

$build_type = $args[0]

quartus_sh -t generate.tcl $build_type

$exitcode = $LASTEXITCODE
if ($exitcode -ne 0) {
  Write-Output "Build failed with $exitcode"
  exit $exitcode
}

$output_file = "snes_main.rev"

if (($build_type -eq "ntsc") -or ($build_type -eq "none")) {
  $output_file = "snes_main.rev"
} elseif (($build_type -eq "pal") -or ($build_type -eq "none_pal")) {
  $output_file = "snes_pal.rev"
} elseif ($build_type -eq "ntsc_spc") {
  $output_file = "snes_spc.rev"
}

F:\Espacio_Trabajo\tools\reverse_bits.exe F:\Espacio_Trabajo\repos\openfpga-SNES-Analogizer\src\fpga\output_files\ap_core.rbf "F:\Espacio_Trabajo\repos\openfpga-SNES-Analogizer\dist\Cores\agg23.SNES_Analogizer\$output_file";
