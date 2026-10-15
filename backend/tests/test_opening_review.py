import pytest

from test_api import system  # noqa: F401 -- shared isolated API fixture


PROPOSAL = {'cash': 1000, 'start_date': '2026-10-01', 'members': {
    'a': {'contribution_balance': 200, 'penalty_debt': 30},
    'b': {'contribution_balance': -100, 'penalty_debt': 0},
}}


def propose(c, t, proposal=PROPOSAL):
    assert c.post('/groups/%2300000001/opening', json=proposal, headers=t['finance']).status_code == 200
    return c.get('/groups/%2300000001', headers=t['president']).json()['opening_proposal']


def test_UX05_16_approval_without_review_precondition_is_rejected(system):
    c, t, _ = system
    propose(c, t)
    assert c.post('/groups/%2300000001/opening/approve', headers=t['president']).status_code == 422
    assert c.get('/groups/%2300000001', headers=t['president']).json()['opening'] is None


@pytest.mark.parametrize('change', [
    {'cash': 1001}, {'start_date': '2026-10-02'},
    {'members': {'a': {'contribution_balance': 201, 'penalty_debt': 30}}},
])
def test_UX05_06_07_stale_review_cannot_approve_replaced_proposal(system, change):
    c, t, _ = system
    reviewed = propose(c, t)
    fresh = propose(c, t, {**PROPOSAL, **change})
    response = c.post('/groups/%2300000001/opening/approve', json={'proposal': reviewed}, headers=t['president'])
    assert response.status_code == 409, response.text
    state = c.get('/groups/%2300000001', headers=t['president']).json()
    assert state['opening'] is None
    assert state['opening_proposal'] == fresh


@pytest.mark.parametrize('role', ['president', 'vice'])
def test_UX05_05_08_11_exact_review_approved_once(system, role):
    c, t, _ = system
    reviewed = propose(c, t)
    body = {'proposal': reviewed}
    assert c.post('/groups/%2300000001/opening/approve', json=body, headers=t[role]).status_code == 200
    assert c.post('/groups/%2300000001/opening/approve', json=body, headers=t[role]).status_code == 409
    state = c.get('/groups/%2300000001', headers=t['president']).json()
    assert state['opening'] == reviewed
    assert state['finances']['cash'] == 1000


@pytest.mark.parametrize('role', ['members', 'admin', 'finance', 'sport'])
def test_UX05_10_other_roles_cannot_approve_even_with_correct_review(system, role):
    c, t, _ = system
    reviewed = propose(c, t)
    assert c.post('/groups/%2300000001/opening/approve', json={'proposal': reviewed}, headers=t[role]).status_code == 403
