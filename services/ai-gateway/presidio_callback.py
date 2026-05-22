from litellm.integrations.custom_logger import CustomLogger
from presidio_analyzer import AnalyzerEngine
from presidio_anonymizer import AnonymizerEngine

_analyzer = AnalyzerEngine()
_anonymizer = AnonymizerEngine()


def _scrub(text: str) -> str:
    results = _analyzer.analyze(text=text, language="en")
    return _anonymizer.anonymize(text=text, analyzer_results=results).text


class PresidioCallback(CustomLogger):
    async def async_pre_call_hook(self, user_api_key_dict, cache, data, call_type):
        if call_type != "completion":
            return data
        messages = data.get("messages", [])
        scrubbed = []
        for m in messages:
            if m.get("role") in ("user", "system") and isinstance(m.get("content"), str):
                scrubbed.append({**m, "content": _scrub(m["content"])})
            else:
                scrubbed.append(m)
        data["messages"] = scrubbed
        return data


presidio_callback = PresidioCallback()
