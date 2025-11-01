import config
import errors
import models/members_db
import models/membership_id
import models/role
import router
import test_helpers.{
  admin_update_form_data, cleanup_test_member, create_test_member_with_details,
  member_form_data, setup_test_db, update_form_data,
}
import wisp/testing

pub fn create_member_success_test() {
  let assert Ok(db_coord) = setup_test_db()
  let test_email = "create@example.com"
  let conf = config.load()

  let _ = cleanup_test_member(db_coord, test_email)
  let form_data = member_form_data(test_email, "New User", "newuser")
  let req = testing.post_form("/members", [], form_data)
  let response = router.handle_request(req, conf, db_coord)

  let assert 303 = response.status
  let _ = cleanup_test_member(db_coord, test_email)
}

pub fn update_member_self_test() {
  let assert Ok(db_coord) = setup_test_db()
  let test_email = "update@example.com"
  let conf = config.load()

  let _ = cleanup_test_member(db_coord, test_email)
  let assert Ok(member) =
    create_test_member_with_details(
      db_coord,
      test_email,
      "pass",
      "Original",
      "orig",
      role.Member,
    )

  let member_id_str = membership_id.to_string(member.membership_id)
  let form_data =
    update_form_data("update@example.com", "Updated Name", "updated")
  let req =
    testing.post_form("/members/" <> member_id_str, [], form_data)
    |> test_helpers.set_session_cookie(member)
  let response = router.handle_request(req, conf, db_coord)

  let assert 303 = response.status
  let _ = cleanup_test_member(db_coord, test_email)
}

pub fn update_member_unauthorized_test() {
  let assert Ok(db_coord) = setup_test_db()
  let test_email = "unauth@example.com"
  let conf = config.load()

  let _ = cleanup_test_member(db_coord, test_email)
  let assert Ok(member) =
    create_test_member_with_details(
      db_coord,
      test_email,
      "pass",
      "User",
      "user",
      role.Member,
    )

  let member_id_str = membership_id.to_string(member.membership_id)
  let form_data = update_form_data("unauth@example.com", "Hacked", "hacker")
  let req = testing.post_form("/members/" <> member_id_str, [], form_data)
  let response = router.handle_request(req, conf, db_coord)

  let assert 401 = response.status
  let _ = cleanup_test_member(db_coord, test_email)
}

pub fn admin_update_member_test() {
  let assert Ok(db_coord) = setup_test_db()
  let admin_email = "admin@example.com"
  let member_email = "target@example.com"
  let conf = config.load()

  let _ = cleanup_test_member(db_coord, admin_email)
  let _ = cleanup_test_member(db_coord, member_email)
  let assert Ok(admin) =
    create_test_member_with_details(
      db_coord,
      admin_email,
      "pass",
      "Admin",
      "admin",
      role.RegStaff,
    )
  let assert Ok(member) =
    create_test_member_with_details(
      db_coord,
      member_email,
      "pass",
      "Target",
      "target",
      role.Member,
    )

  let member_id_str = membership_id.to_string(member.membership_id)
  let form_data =
    admin_update_form_data(
      "target@example.com",
      "Admin Updated",
      "adminupdated",
      "Member",
    )
  let req =
    testing.post_form("/admin/members/" <> member_id_str, [], form_data)
    |> test_helpers.set_session_cookie(admin)
  let response = router.handle_request(req, conf, db_coord)

  let assert 303 = response.status
  let _ = cleanup_test_member(db_coord, admin_email)
  let _ = cleanup_test_member(db_coord, member_email)
}

pub fn delete_member_test() {
  let assert Ok(db_coord) = setup_test_db()
  let admin_email = "deleteadmin@example.com"
  let target_email = "deletetarget@example.com"
  let conf = config.load()

  let _ = cleanup_test_member(db_coord, admin_email)
  let _ = cleanup_test_member(db_coord, target_email)
  let assert Ok(admin) =
    create_test_member_with_details(
      db_coord,
      admin_email,
      "pass",
      "Admin",
      "admin",
      role.RegStaff,
    )
  let assert Ok(target) =
    create_test_member_with_details(
      db_coord,
      target_email,
      "pass",
      "Target",
      "target",
      role.Member,
    )

  let target_id_str = membership_id.to_string(target.membership_id)
  let req =
    testing.post("/members/" <> target_id_str <> "/delete", [], "")
    |> test_helpers.set_session_cookie(admin)
  let response = router.handle_request(req, conf, db_coord)

  let assert 200 = response.status

  // Verify member is no longer accessible via get()
  let get_result = members_db.get(db_coord, target.membership_id)
  let assert Error(errors.NotFoundError(_)) = get_result

  let _ = cleanup_test_member(db_coord, admin_email)
  let _ = cleanup_test_member(db_coord, target_email)
}

pub fn delete_member_unauthorized_test() {
  let assert Ok(db_coord) = setup_test_db()
  let test_email = "nodelete@example.com"
  let conf = config.load()

  let _ = cleanup_test_member(db_coord, test_email)
  let assert Ok(member) =
    create_test_member_with_details(
      db_coord,
      test_email,
      "pass",
      "No Delete",
      "nodelete",
      role.Member,
    )

  let member_id_str = membership_id.to_string(member.membership_id)
  let req = testing.post("/members/" <> member_id_str <> "/delete", [], "")
  let response = router.handle_request(req, conf, db_coord)

  let assert 401 = response.status
  let _ = cleanup_test_member(db_coord, test_email)
}
