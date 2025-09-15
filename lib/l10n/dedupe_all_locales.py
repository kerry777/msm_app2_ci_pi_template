# dedupe_all_locales.py
import re

# ▶▶▶ 본인 환경에 맞게 경로만 수정하세요 (raw string)
input_path  = r'C:\projects\mdm_app\mdm_app5\client\lib\l10n\app_localizations.dart'
output_path = r'C:\projects\mdm_app\mdm_app5\client\lib\l10n\app_localizations_clean.dart'

# 파일 읽기
with open(input_path, 'r', encoding='utf-8') as f:
    content = f.read()

# _localizedValues 블록 전체(여는 중괄호부터 닫는 };까지) 추출
m = re.search(
    r'(static const Map<String, Map<String, String>> _localizedValues = \{)'  # 블록 시작
    r'([\s\S]*?)'                                                         # 중간 전체
    r'(\s*\};)',                                                         # 블록 끝
    content
)
if not m:
    raise RuntimeError("`_localizedValues` 블록을 찾을 수 없습니다. 파일 경로와 내용을 확인하세요.")

prefix, body, suffix = m.groups()

def clean_block(block: str) -> str:
    seen = set()
    out = []
    for line in block.splitlines():
        # 'key': 'value', 형태만 체크
        kv = re.match(r"(\s*)'([^']+)'\s*:\s*'([^']*)',", line)
        if kv:
            key = kv.group(2)
            if key in seen:
                continue
            seen.add(key)
        out.append(line)
    return '\n'.join(out)

# 각 로케일 섹션('en', 'ko', ...)에서 중복 제거
def dedupe_locales(text: str) -> str:
    def repl(m2):
        header, locale, block, footer = m2.groups()
        cleaned = clean_block(block)
        return f"{header}\n{cleaned}\n{footer}"
    return re.sub(
        r"('([a-z]{2})'\s*:\s*\{)"  # 'en': {  or  'ko': {
        r"([\s\S]*?)"               # 그 사이 모든 내용
        r"(\n\s*\},)",              # 닫고 뒤에 콤마
        repl, text, flags=re.MULTILINE
    )

new_body = dedupe_locales(body)
new_content = prefix + new_body + suffix

# 결과 쓰기
with open(output_path, 'w', encoding='utf-8') as f:
    f.write(new_content)

print(f"✅ 중복 제거 완료: {output_path}")
