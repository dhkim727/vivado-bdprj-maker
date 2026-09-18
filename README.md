# Vivado 빌드 수행 참조

## 1. Vivado 버전 : 2025.2,  두 Vivado GUI세션을 열고 동시에 OOC 하지 마세요

## 2. 권장 사양 : 64GB RAM >64GB SWAP 공간

## 3. Vivado 프로젝트 생성 직후에만 프로젝트 열때 시간이 오래걸릴 수 있습니다.

## 4. Vivado 프로젝트 생성 직후 GUI에서 OOC를 직접 수행했을때 시스템 메모리가 부족하면 메모리 부족으로 꺼져버릴 수 있습니다. make 명령을 사용하면 메모리 부족으로 빌드가 실패하는 일은 없습니다.

## 5. 현재 이 프로젝트는 두 모델을 동시에 make 빌드 할 수 없으므로 두 모델 전환은 vivado 프로젝트를 열어서 수행하세요.

## 6. Vivado 프로젝트 수정 후 make update_tcl 수행을 잊지 말아주세요.

## 7. IP 업데이트는 ips 폴더에 들어가서 make clean 후 part 명을 직접 기입해 다시 빌드 후 Vivado 프로젝트에서 Refresh IP catalog -> upgrade ip로 수행하시면 됩니다. vivado 프로젝트 전체를 다시 생성하실 필요는 없습니다.


