from temporalio import workflow

@workflow.defn
class HelloWorkflow:
    def __init__(self):
        self._name = ""
        self._suffix = "!"
    
    @workflow.run
    async def run(self, name: str) -> str:
        self._name = name
        return f"Hello, {self._name}{self._suffix}"
    
    @workflow.signal
    def set_suffix(self, suffix: str):
        self._suffix = suffix
    
    @workflow.query
    def get_state(self) -> str:
        return f"Current name: {self._name}, suffix: {self._suffix}"