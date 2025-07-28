import pytest
from ..workflows import HelloWorkflow, HealthCheckWorkflow, Text2ImageWorkflow, WorkflowType

def test_workflow_type_enum():
    """Test the WorkflowType enum."""
    assert WorkflowType.HELLO.value == "hello"
    assert WorkflowType.HEALTH_CHECK.value == "health_check"
    assert WorkflowType.TEXT2IMAGE.value == "text2image"

def test_hello_workflow_initialization():
    """Test that HelloWorkflow can be instantiated."""
    workflow = HelloWorkflow()
    assert workflow._name is None
    assert workflow._suffix == "!"

def test_hello_workflow_set_suffix():
    """Test the set_suffix signal method."""
    workflow = HelloWorkflow()
    workflow.set_suffix(" from Test!")
    assert workflow._suffix == " from Test!"

def test_hello_workflow_get_state():
    """Test the get_state query method."""
    workflow = HelloWorkflow()
    workflow._name = "Test"
    workflow._suffix = " from Test!"
    
    state = workflow.get_state()
    assert state["name"] == "Test"
    assert state["suffix"] == " from Test!"

def test_health_check_workflow_initialization():
    """Test that HealthCheckWorkflow can be instantiated."""
    workflow = HealthCheckWorkflow()
    assert workflow._containers == []
    assert workflow._health_results == {}

def test_health_check_workflow_add_container():
    """Test the add_container signal method."""
    workflow = HealthCheckWorkflow()
    workflow.add_container("test-container")
    assert "test-container" in workflow._containers
    
    # Test duplicate prevention
    workflow.add_container("test-container")
    assert workflow._containers.count("test-container") == 1

def test_health_check_workflow_get_health_summary():
    """Test the health summary calculation."""
    workflow = HealthCheckWorkflow()
    
    # Test empty results
    summary = workflow._get_health_summary()
    assert summary == {"total": 0, "healthy": 0, "unhealthy": 0, "errors": 0}
    
    # Test with some results
    workflow._health_results = {
        "container1": {"status": "healthy"},
        "container2": {"status": "unhealthy"},
        "container3": {"status": "error"},
        "container4": {"status": "healthy"}
    }
    
    summary = workflow._get_health_summary()
    assert summary["total"] == 4
    assert summary["healthy"] == 2
    assert summary["unhealthy"] == 1
    assert summary["errors"] == 1

def test_text2image_workflow_initialization():
    """Test that Text2ImageWorkflow can be instantiated."""
    workflow = Text2ImageWorkflow()
    assert workflow._prompt == ""
    assert workflow._image_url is None
    assert workflow._status == "pending"
    assert workflow._progress == 0

def test_text2image_workflow_update_progress():
    """Test the update_progress signal method."""
    workflow = Text2ImageWorkflow()
    
    workflow.update_progress(50)
    assert workflow._progress == 50
    
    # Test bounds
    workflow.update_progress(150)  # Should be capped at 100
    assert workflow._progress == 100
    
    workflow.update_progress(-10)  # Should be capped at 0
    assert workflow._progress == 0

def test_text2image_workflow_cancel():
    """Test the cancel_generation signal method."""
    workflow = Text2ImageWorkflow()
    workflow.cancel_generation()
    assert workflow._status == "cancelled"

def test_text2image_workflow_get_status():
    """Test the get_status query method."""
    workflow = Text2ImageWorkflow()
    workflow._prompt = "Test prompt"
    workflow._status = "generating"
    workflow._progress = 75
    workflow._image_url = "https://example.com/image.png"
    
    status = workflow.get_status()
    assert status["prompt"] == "Test prompt"
    assert status["status"] == "generating"
    assert status["progress"] == 75
    assert status["image_url"] == "https://example.com/image.png" 