defmodule NervesHubAPIWeb.DeploymentControllerTest do
  use NervesHubAPIWeb.ConnCase, async: true

  alias NervesHubWebCore.{AuditLogs, Deployments.Deployment, Fixtures}

  describe "index" do
    test "lists all deployments", %{conn: conn, org: org, product: product} do
      conn = get(conn, deployment_path(conn, :index, org.name, product.name))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create deployment" do
    setup context do
      org_key = Fixtures.org_key_fixture(context.org)
      firmware = Fixtures.firmware_fixture(org_key, context.product)

      params = %{
        name: "test",
        firmware: firmware.uuid,
        firmware_id: firmware.id,
        conditions: %{
          version: "",
          tags: ["test"]
        },
        is_active: false
      }

      context
      |> Map.put(:org_key, org_key)
      |> Map.put(:firmware, firmware)
      |> Map.put(:params, params)
    end

    test "renders deployment when data is valid", %{
      conn: conn,
      org: org,
      params: params,
      product: product
    } do
      conn = post(conn, deployment_path(conn, :create, org.name, product.name), params)
      assert json_response(conn, 201)["data"]

      conn = get(conn, deployment_path(conn, :show, org.name, product.name, params.name))
      assert json_response(conn, 200)["data"]["name"] == params.name
    end

    test "audits on success", %{
      conn: conn,
      org: org,
      params: params,
      product: product,
      user: user
    } do
      conn = post(conn, deployment_path(conn, :create, org.name, product.name), params)
      assert json_response(conn, 201)["data"]

      [audit_log] = AuditLogs.logs_by(user)
      assert audit_log.resource_type == Deployment
      assert audit_log.params["firmware_id"] == params.firmware_id
      assert audit_log.params["name"] == params.name
    end

    test "renders errors when data is invalid", %{conn: conn, org: org, product: product} do
      conn = post(conn, deployment_path(conn, :create, org.name, product.name))
      assert json_response(conn, 500)["errors"] != %{}
    end
  end

  describe "update deployment" do
    setup [:create_deployment]

    test "renders deployment when data is valid", %{
      conn: conn,
      deployment: deployment,
      org: org,
      product: product
    } do
      path = deployment_path(conn, :update, org.name, product.name, deployment.name)
      conn = put(conn, path, deployment: %{"is_active" => true})
      assert %{"is_active" => true} = json_response(conn, 200)["data"]

      path = deployment_path(conn, :show, org.name, product.name, deployment.name)
      conn = get(conn, path)
      assert json_response(conn, 200)["data"]["is_active"]
    end

    test "audits on success", %{conn: conn, deployment: deployment, org: org, product: product} do
      path = deployment_path(conn, :update, org.name, product.name, deployment.name)
      conn = put(conn, path, deployment: %{"is_active" => true})
      assert json_response(conn, 200)["data"]

      [audit_log] = AuditLogs.logs_for(deployment)
      assert audit_log.resource_type == Deployment
      assert audit_log.changes == %{"is_active" => true}
    end

    test "renders errors when data is invalid", %{
      conn: conn,
      deployment: deployment,
      org: org,
      product: product
    } do
      path = deployment_path(conn, :update, org.name, product.name, deployment.name)
      conn = put(conn, path, deployment: %{is_active: "1234"})
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete deployment" do
    setup [:create_deployment]

    test "deletes chosen deployment", %{
      conn: conn,
      org: org,
      product: product,
      deployment: deployment
    } do
      conn = delete(conn, deployment_path(conn, :delete, org.name, product.name, deployment.name))
      assert response(conn, 204)

      conn = get(conn, deployment_path(conn, :show, org.name, product.name, deployment.name))

      assert response(conn, 404)
    end
  end

  defp create_deployment(%{org: org, product: product}) do
    org_key = Fixtures.org_key_fixture(org)
    firmware = Fixtures.firmware_fixture(org_key, product)
    deployment = Fixtures.deployment_fixture(firmware)
    {:ok, %{deployment: deployment}}
  end
end
